#!/usr/bin/env python3
"""
Local Leaderboard Test Script
GitHub Actions'a göndermeden önce local'de test etmek için kullanın.

Kullanım:
1. .env dosyasında SUPABASE_URL ve SUPABASE_ANON_KEY olduğundan emin olun
2. pip install supabase python-dotenv
3. python test_leaderboard_local.py
"""

import os
from datetime import datetime
from dotenv import load_dotenv
from supabase import create_client, Client


def main():
    # .env dosyasını yükle
    load_dotenv()

    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_ANON_KEY")

    if not supabase_url or not supabase_key:
        print("❌ HATA: .env dosyasında SUPABASE_URL ve SUPABASE_ANON_KEY bulunamadı!")
        print("\n.env dosyanızı kontrol edin:")
        print("SUPABASE_URL=https://your-project.supabase.co")
        print("SUPABASE_ANON_KEY=eyJ...")
        return

    print(f"🔗 Supabase'e bağlanılıyor: {supabase_url}")

    try:
        # Supabase client oluştur
        supabase: Client = create_client(supabase_url, supabase_key)
        print("✅ Bağlantı başarılı!")

        print(
            f"\n🚀 Leaderboard testi başladı: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        )
        print("-" * 60)

        # 1. Mevcut kullanıcı sayısını kontrol et
        print("\n📊 Kullanıcı istatistikleri:")
        profiles = supabase.from_("profiles").select("id", count="exact").execute()
        print(f"   Toplam kullanıcı: {profiles.count}")

        # 2. Puanları güncelle
        print("\n🔄 Kullanıcı puanları güncelleniyor...")
        result = supabase.rpc("update_all_user_points").execute()
        print("   ✅ Puanlar güncellendi")

        # 3. Top 10 kullanıcıyı göster
        print("\n🏆 Top 10 Kullanıcı:")
        top_users = (
            supabase.from_("profiles")
            .select("username, total_points")
            .order("total_points", desc=True)
            .limit(10)
            .execute()
        )

        if top_users.data:
            for i, user in enumerate(top_users.data, 1):
                medal = (
                    "🥇" if i == 1 else "🥈" if i == 2 else "🥉" if i == 3 else f"{i}."
                )
                print(f"   {medal} {user['username']}: {user['total_points']} puan")
        else:
            print("   Henüz puanlı kullanıcı yok")

        # 4. Snapshot oluştur
        print("\n📸 Günlük snapshot oluşturuluyor...")
        snapshot_result = supabase.rpc("create_daily_leaderboard_snapshot").execute()
        print("   ✅ Snapshot oluşturuldu")

        # 5. Snapshot'ı kontrol et
        print("\n📅 Son snapshot:")
        latest_snapshot = (
            supabase.from_("leaderboard_snapshots")
            .select("*", count="exact")
            .order("snapshot_date", desc=True)
            .limit(1)
            .execute()
        )

        if latest_snapshot.data:
            snapshot = latest_snapshot.data[0]
            print(f"   Tarih: {snapshot['snapshot_date']}")
            print(f"   Toplam kayıt: {latest_snapshot.count}")

        # 6. Puan dağılımı istatistikleri
        print("\n📈 Puan dağılımı:")
        stats = (
            supabase.from_("profiles")
            .select("total_points")
            .order("total_points", desc=True)
            .execute()
        )

        if stats.data:
            points = [u["total_points"] for u in stats.data if u["total_points"] > 0]
            if points:
                print(f"   En yüksek: {max(points)} puan")
                print(f"   Ortalama: {sum(points) // len(points)} puan")
                print(f"   Puanlı kullanıcı: {len(points)}")

        print("\n" + "-" * 60)
        print(f"✨ Test tamamlandı: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("\n✅ Her şey çalışıyor! GitHub Actions'a gönderebilirsiniz.")

    except Exception as e:
        print(f"\n❌ HATA: {str(e)}")
        print("\nSorun giderme:")
        print("1. Supabase URL ve key'in doğru olduğunu kontrol edin")
        print("2. LEADERBOARD_SETUP.sql dosyasının çalıştırıldığından emin olun")
        print("3. RLS politikalarının doğru ayarlandığını kontrol edin")


if __name__ == "__main__":
    main()
