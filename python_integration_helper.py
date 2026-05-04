"""
Eksik Kafe Bildirimleri - Python Pipeline Entegrasyonu
Bu script Flutter Admin Panel'den export edilen verileri alır ve işler
"""

import json
import csv
from typing import List, Dict
from datetime import datetime

class KafeBildirimProcessor:
    """
    Flutter Admin Panel'den gelen bildirimler işlenir
    """
    
    def __init__(self):
        self.processed_cafes = []
    
    def load_from_json(self, json_string: str) -> List[Dict]:
        """
        Admin panel'den kopyalanan JSON verisini yükle
        
        Kullanım:
        1. Admin Panel'de "JSON Export" butonuna bas
        2. Panoya kopyalanan veriyi buraya yapıştır
        """
        try:
            data = json.loads(json_string)
            print(f"✅ {len(data)} bildirim yüklendi")
            return data
        except json.JSONDecodeError as e:
            print(f"❌ JSON parse hatası: {e}")
            return []
    
    def load_from_csv(self, csv_string: str) -> List[Dict]:
        """
        Admin panel'den kopyalanan CSV verisini yükle
        
        Kullanım:
        1. Admin Panel'de "CSV Export" butonuna bas
        2. Panoya kopyalanan veriyi buraya yapıştır
        """
        try:
            lines = csv_string.strip().split('\n')
            reader = csv.DictReader(lines)
            data = list(reader)
            print(f"✅ {len(data)} bildirim yüklendi")
            return data
        except Exception as e:
            print(f"❌ CSV parse hatası: {e}")
            return []
    
    def process_bildirim(self, bildirim: Dict) -> Dict:
        """
        Tek bir bildirimi işle ve Google Maps API için hazırla
        
        Returns:
            {
                'name': str,
                'latitude': float,
                'longitude': float,
                'notes': str,
                'source': 'user_report'
            }
        """
        return {
            'id': bildirim.get('id'),
            'name': bildirim.get('kafe_adi'),
            'latitude': float(bildirim.get('latitude')),
            'longitude': float(bildirim.get('longitude')),
            'notes': bildirim.get('notlar', ''),
            'user_email': bildirim.get('kullanici_email'),
            'created_at': bildirim.get('created_at'),
            'source': 'user_report'
        }
    
    def batch_process(self, bildirimler: List[Dict]) -> List[Dict]:
        """
        Tüm bildirimleri toplu işle
        """
        processed = []
        for bildirim in bildirimler:
            try:
                processed_item = self.process_bildirim(bildirim)
                processed.append(processed_item)
                print(f"✅ İşlendi: {processed_item['name']}")
            except Exception as e:
                print(f"❌ Hata ({bildirim.get('kafe_adi')}): {e}")
        
        self.processed_cafes = processed
        return processed
    
    def export_for_google_maps_api(self) -> List[Dict]:
        """
        Google Maps API için format
        
        Senin mevcut pipeline'ına uygun format:
        {
            'name': 'Kafe Adı',
            'lat': 41.0082,
            'lng': 28.9784
        }
        """
        return [
            {
                'name': cafe['name'],
                'lat': cafe['latitude'],
                'lng': cafe['longitude'],
                'user_notes': cafe['notes']
            }
            for cafe in self.processed_cafes
        ]
    
    def save_to_file(self, filename: str = 'pending_cafes.json'):
        """
        İşlenmiş verileri dosyaya kaydet
        """
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(self.processed_cafes, f, ensure_ascii=False, indent=2)
        print(f"✅ {len(self.processed_cafes)} kafe {filename} dosyasına kaydedildi")


# ============================================
# KULLANIM ÖRNEĞİ
# ============================================

if __name__ == "__main__":
    processor = KafeBildirimProcessor()
    
    # ADIM 1: Admin Panel'den JSON verisini kopyala
    # Admin Panel > JSON Export > Panoya kopyala
    
    json_data = """
    [
        {
            "id": "uuid-here",
            "kafe_adi": "Kahve Dükkanı",
            "latitude": 41.0082,
            "longitude": 28.9784,
            "notlar": "Kadıköy rıhtımda",
            "kullanici_email": "user@example.com",
            "created_at": "2026-05-04T10:30:00Z"
        }
    ]
    """
    
    # ADIM 2: Verileri yükle
    bildirimler = processor.load_from_json(json_data)
    
    # ADIM 3: İşle
    processed = processor.batch_process(bildirimler)
    
    # ADIM 4: Google Maps API formatına çevir
    google_maps_data = processor.export_for_google_maps_api()
    
    print("\n📊 Google Maps API için hazır veri:")
    print(json.dumps(google_maps_data, ensure_ascii=False, indent=2))
    
    # ADIM 5: Dosyaya kaydet
    processor.save_to_file('pending_cafes.json')
    
    print("\n✅ İşlem tamamlandı!")
    print(f"📁 {len(processed)} kafe işlendi")
    print("\n🔄 Şimdi yapılacaklar:")
    print("1. pending_cafes.json dosyasını aç")
    print("2. Her kafe için Google Maps API'den veri çek")
    print("3. SBERT ile embedding oluştur")
    print("4. ilce_isimli_kafeler tablosuna ekle")
    print("5. Admin Panel'de durumu 'eklendi' olarak güncelle")


# ============================================
# MEVCUT PIPELINE'INA ENTEGRASYON
# ============================================

"""
Senin mevcut Python koduna entegre etmek için:

1. Bu script'i import et:
   from python_integration_helper import KafeBildirimProcessor

2. Admin Panel'den veriyi al:
   processor = KafeBildirimProcessor()
   bildirimler = processor.load_from_json(json_data)
   processed = processor.batch_process(bildirimler)

3. Mevcut pipeline'ına gönder:
   for cafe in processor.export_for_google_maps_api():
       # Senin mevcut fonksiyonun
       google_maps_data = fetch_from_google_maps(cafe['name'], cafe['lat'], cafe['lng'])
       embedding = create_sbert_embedding(google_maps_data)
       save_to_supabase(cafe, google_maps_data, embedding)

4. Başarılı olduysa Supabase'de durumu güncelle:
   supabase.table('eksik_kafe_bildirimleri')
       .update({'durum': 'eklendi'})
       .eq('id', cafe['id'])
       .execute()
"""
