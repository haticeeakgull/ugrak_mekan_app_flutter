"""
Admin Panel → Python Pipeline Entegrasyonu
Flutter Admin Panel'den gelen bildirimleri otomatik işler
"""

import os
import json
import time
import torch
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from geopy.geocoders import Nominatim
from supabase import create_client
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer

# --- AYARLAR ---
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# ✅ SBERT MODEL (384)
model = SentenceTransformer(
    "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
)

BRAVE_PATH = r"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
BRAVE_PROFILE = r"C:\Users\hakgl\AppData\Local\BraveSoftware\Brave-Browser\User Data"
JSON_BACKUP_FILE = "istanbul_kafeleri_yedek.json"

vibe_sozlugu = {
    "salaş": ["salaş", "samimi", "mütevazı", "eski usul"],
    "ders-çalışmalık": ["ders", "çalışma", "laptop", "priz", "sessiz", "odaklanma"],
    "sosyal-canlı": ["canlı", "kalabalık", "müzik", "hareketli", "popüler"],
    "kafa-dinlemelik": ["huzur", "dingin", "sakin", "tenha", "dinlendirici"],
}


# ------------------------------
# ✅ SBERT VECTOR
# ------------------------------
def get_vector(reviews):
    if not reviews:
        return []
    full_text = " ".join(reviews)
    embedding = model.encode(full_text, normalize_embeddings=True)
    return embedding.tolist()


# ------------------------------
# DB CHECK
# ------------------------------
def check_if_exists(kafe_adi, lat, lon):
    try:
        res = (
            supabase.table("ilce_isimli_kafeler")
            .select("id")
            .eq("kafe_adi", kafe_adi)
            .eq("latitude", lat)
            .eq("longitude", lon)
            .execute()
        )
        return len(res.data) > 0
    except:
        return False


# ------------------------------
# JSON BACKUP
# ------------------------------
def save_to_json_backup(data):
    file_data = []
    if os.path.exists(JSON_BACKUP_FILE):
        with open(JSON_BACKUP_FILE, "r", encoding="utf-8") as f:
            try:
                file_data = json.load(f)
            except:
                file_data = []
    file_data.append(data)
    with open(JSON_BACKUP_FILE, "w", encoding="utf-8") as f:
        json.dump(file_data, f, ensure_ascii=False, indent=4)


def scrape_reviews(place_name, lat, lon):
    chrome_options = Options()
    chrome_options.binary_location = BRAVE_PATH
    chrome_options.add_argument(f"--user-data-dir={BRAVE_PROFILE}")
    chrome_options.add_argument("--profile-directory=Default")
    chrome_options.add_argument("--lang=tr-TR")
    chrome_options.add_experimental_option(
        "prefs", {"intl.accept_languages": "tr,tr-TR"}
    )
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])

    driver = webdriver.Chrome(options=chrome_options)
    wait = WebDriverWait(driver, 15)
    reviews = []

    try:
        url = f"https://www.google.com/maps/search/{place_name}/@{lat},{lon},17z?hl=tr"
        driver.get(url)
        time.sleep(5)

        try:
            btn = wait.until(
                EC.element_to_be_clickable(
                    (
                        By.XPATH,
                        '//button[contains(@aria-label, "Yorumlar") or contains(@aria-label, "Reviews")]',
                    )
                )
            )
            btn.click()
            time.sleep(3)
        except:
            print("Yorum butonu bulunamadı")
            return []

        scrollable_div = None
        selectors = ["div.m6QErb.DxyBCb", "div.m6QErb"]
        for selector in selectors:
            try:
                scrollable_div = driver.find_element(By.CSS_SELECTOR, selector)
                if scrollable_div:
                    break
            except:
                continue

        for _ in range(10):
            if scrollable_div:
                driver.execute_script(
                    "arguments[0].scrollTop = arguments[0].scrollHeight", scrollable_div
                )
            else:
                driver.execute_script("window.scrollBy(0, 1000);")
            time.sleep(1.5)

        spans = driver.find_elements(By.CLASS_NAME, "wiI7pd")
        reviews = [s.text.strip() for s in spans if s.text.strip()]
    except Exception as e:
        print("SCRAPER HATA:", e)
    finally:
        driver.quit()

    return list(set(reviews))


# ------------------------------
# LOCATION
# ------------------------------
def get_location_details(lat, lon):
    geolocator = Nominatim(user_agent="ugrak_mekan")
    try:
        location = geolocator.reverse(f"{lat}, {lon}", timeout=10)
        addr = location.raw.get("address", {})
        semt = addr.get("suburb") or addr.get("neighbourhood") or "Bilinmiyor"
        ilce = addr.get("city") or addr.get("town") or "Bilinmiyor"
        return semt, ilce
    except:
        return "Bilinmiyor", "Bilinmiyor"


# ------------------------------
# VIBES
# ------------------------------
def get_vibes(reviews):
    text = " ".join(reviews).lower()
    active_vibes = []
    for vibe, keywords in vibe_sozlugu.items():
        if sum(1 for k in keywords if k in text) >= 2:
            active_vibes.append(vibe)
    return active_vibes


# ------------------------------
# DB UPLOAD
# ------------------------------
def upload_to_supabase(final_data):
    try:
        res_cafe = (
            supabase.table("ilce_isimli_kafeler")
            .insert(
                {
                    "kafe_adi": final_data["isim"],
                    "latitude": final_data["lat"],
                    "longitude": final_data["lon"],
                    "ilce_adi": final_data["ilce_adi"],
                    "semt_adi": final_data["semt_adi"],
                    "embedding_v2": final_data["vektor"],
                    "vibe_etiketleri": final_data["vibe_etiketleri"],
                    "ozellikler": final_data["yorumlar"],
                }
            )
            .execute()
        )

        if res_cafe.data:
            new_id = res_cafe.data[0]["id"]
            for yorum in final_data["yorumlar"]:
                supabase.table("cafe_yorumlar").insert(
                    {
                        "cafe_id": new_id,
                        "yorum_metni": yorum,
                        "puan": 5,
                    }
                ).execute()
            return True, new_id
    except Exception as e:
        print("DB HATA:", e)
        return False, None


# ------------------------------
# ✅ YENİ: ADMIN PANEL ENTEGRASYONU
# ------------------------------
def process_admin_bildirim(bildirim_json):
    """
    Admin Panel'den gelen JSON'u işle

    Kullanım:
    1. Admin Panel'de "Python'a Gönder" butonuna bas
    2. JSON panoya kopyalanır
    3. Buraya yapıştır
    """
    try:
        # JSON parse
        if isinstance(bildirim_json, str):
            bildirim = json.loads(bildirim_json)
        else:
            bildirim = bildirim_json

        bildirim_id = bildirim.get("id")
        name = bildirim.get("kafe_adi")
        lat = float(bildirim.get("latitude"))
        lon = float(bildirim.get("longitude"))
        notlar = bildirim.get("notlar", "")

        print(f"\n{'='*50}")
        print(f"📍 İŞLENİYOR: {name}")
        print(f"{'='*50}")

        # 1. Zaten var mı kontrol et
        if check_if_exists(name, lat, lon):
            print("❌ Bu kafe zaten veritabanında var!")
            return False, "Zaten mevcut"

        # 2. Google Maps'ten yorumları çek
        print("🔍 Google Maps'ten yorumlar çekiliyor...")
        reviews = scrape_reviews(name, lat, lon)

        if not reviews:
            print("⚠️ Yorum bulunamadı, kullanıcı notlarını kullanıyoruz...")
            reviews = [notlar] if notlar else ["Kullanıcı bildirimi"]
        else:
            print(f"✅ {len(reviews)} yorum çekildi")

        # 3. Konum detaylarını al
        print("📍 Konum detayları alınıyor...")
        semt, ilce = get_location_details(lat, lon)
        print(f"✅ Semt: {semt}, İlçe: {ilce}")

        # 4. SBERT embedding oluştur
        print("🧠 SBERT embedding oluşturuluyor...")
        vektor = get_vector(reviews)
        print(f"✅ Embedding oluşturuldu (boyut: {len(vektor)})")

        # 5. Vibe etiketlerini belirle
        print("🏷️ Vibe etiketleri belirleniyor...")
        vibes = get_vibes(reviews)
        print(f"✅ Vibe'lar: {vibes if vibes else 'Yok'}")

        # 6. Veriyi hazırla
        data = {
            "isim": name,
            "lat": lat,
            "lon": lon,
            "yorumlar": reviews,
            "vektor": vektor,
            "semt_adi": semt,
            "ilce_adi": ilce,
            "vibe_etiketleri": vibes,
        }

        # 7. JSON backup
        save_to_json_backup(data)
        print("✅ JSON backup kaydedildi")

        # 8. Veritabanına yükle
        print("💾 Veritabanına yükleniyor...")
        success, cafe_id = upload_to_supabase(data)

        if success:
            print(f"✅ BAŞARILI! Kafe ID: {cafe_id}")

            # 9. Bildirim durumunu güncelle
            try:
                supabase.table("eksik_kafe_bildirimleri").update(
                    {"durum": "eklendi"}
                ).eq("id", bildirim_id).execute()
                print("✅ Bildirim durumu 'eklendi' olarak güncellendi")
            except Exception as e:
                print(f"⚠️ Bildirim güncellenemedi: {e}")

            return True, cafe_id
        else:
            print("❌ Veritabanına yüklenemedi")
            return False, "DB hatası"

    except Exception as e:
        print(f"❌ HATA: {e}")
        return False, str(e)


# ------------------------------
# ✅ TOPLU İŞLEME
# ------------------------------
def process_batch_from_admin(json_array):
    """
    Admin Panel'den toplu export edilen JSON array'i işle

    Kullanım:
    1. Admin Panel'de "JSON Export" butonuna bas
    2. Tüm liste panoya kopyalanır
    3. Buraya yapıştır
    """
    try:
        if isinstance(json_array, str):
            bildirimler = json.loads(json_array)
        else:
            bildirimler = json_array

        print(f"\n{'='*50}")
        print(f"📦 TOPLU İŞLEME: {len(bildirimler)} bildirim")
        print(f"{'='*50}\n")

        basarili = 0
        basarisiz = 0

        for i, bildirim in enumerate(bildirimler, 1):
            print(f"\n[{i}/{len(bildirimler)}] İşleniyor...")
            success, result = process_admin_bildirim(bildirim)

            if success:
                basarili += 1
            else:
                basarisiz += 1

            # Rate limiting
            if i < len(bildirimler):
                print("\n⏳ 5 saniye bekleniyor...")
                time.sleep(5)

        print(f"\n{'='*50}")
        print(f"📊 ÖZET")
        print(f"{'='*50}")
        print(f"✅ Başarılı: {basarili}")
        print(f"❌ Başarısız: {basarisiz}")
        print(f"📊 Toplam: {len(bildirimler)}")

    except Exception as e:
        print(f"❌ TOPLU İŞLEME HATASI: {e}")


# ------------------------------
# MANUEL KULLANIM (ESKİ YÖNTEMİN KORUNMASI)
# ------------------------------
def run_pipeline_manual():
    """Eski manuel yöntem - hala kullanılabilir"""
    name = input("Kafe adı: ")
    lat = float(input("Lat: "))
    lon = float(input("Lon: "))

    if check_if_exists(name, lat, lon):
        print("Zaten var")
        return

    reviews = scrape_reviews(name, lat, lon)
    if not reviews:
        print("Yorum yok")
        return

    semt, ilce = get_location_details(lat, lon)

    data = {
        "isim": name,
        "lat": lat,
        "lon": lon,
        "yorumlar": reviews,
        "vektor": get_vector(reviews),
        "semt_adi": semt,
        "ilce_adi": ilce,
        "vibe_etiketleri": get_vibes(reviews),
    }

    save_to_json_backup(data)
    success, cafe_id = upload_to_supabase(data)

    if success:
        print(f"BAŞARILI - Kafe ID: {cafe_id}")


# ------------------------------
# MAIN
# ------------------------------
if __name__ == "__main__":
    print("\n" + "=" * 50)
    print("🎯 UGRAK MEKAN - ADMIN PIPELINE")
    print("=" * 50)
    print("\n1. Tek bildirim işle (Admin Panel'den JSON)")
    print("2. Toplu işle (Admin Panel'den JSON array)")
    print("3. Manuel giriş (eski yöntem)")

    secim = input("\nSeçim (1/2/3): ").strip()

    if secim == "1":
        print("\n📋 Admin Panel'den kopyalanan JSON'u yapıştır:")
        json_input = input().strip()
        process_admin_bildirim(json_input)

    elif secim == "2":
        print("\n📋 Admin Panel'den kopyalanan JSON array'i yapıştır:")
        json_input = input().strip()
        process_batch_from_admin(json_input)

    elif secim == "3":
        run_pipeline_manual()

    else:
        print("❌ Geçersiz seçim!")
