#!/usr/bin/env python3
"""
Daily Leaderboard Update Script
Bu script GitHub Actions tarafından her gün çalıştırılır ve:
1. Tüm kullanıcıların puanlarını günceller
2. Günlük leaderboard snapshot'ı oluşturur
"""

import os
import sys
from datetime import datetime
from supabase import create_client, Client


def main():
    # Environment variables'ları al
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_ANON_KEY")

    if not supabase_url or not supabase_key:
        print(
            "❌ HATA: SUPABASE_URL ve SUPABASE_ANON_KEY environment variables gerekli!"
        )
        sys.exit(1)

    # Supabase client oluştur
    supabase: Client = create_client(supabase_url, supabase_key)

    print(f"🚀 Leaderboard güncelleme başladı: {datetime.now().isoformat()}")

    try:
        # 1. Tüm kullanıcıların puanlarını güncelle
        print("📊 Kullanıcı puanları hesaplanıyor...")
        result = supabase.rpc("update_all_user_points").execute()
        print(f"✅ Kullanıcı puanları güncellendi")

        # 2. Günlük snapshot oluştur
        print("📸 Günlük snapshot oluşturuluyor...")
        snapshot_result = supabase.rpc("create_daily_leaderboard_snapshot").execute()
        print(f"✅ Snapshot oluşturuldu")

        # 3. İstatistikleri göster
        stats = (
            supabase.from_("profiles").select("total_points", count="exact").execute()
        )
        total_users = stats.count if stats.count else 0

        # En yüksek puanı al
        top_user = (
            supabase.from_("profiles")
            .select("username, total_points")
            .order("total_points", desc=True)
            .limit(1)
            .execute()
        )

        if top_user.data and len(top_user.data) > 0:
            top = top_user.data[0]
            print(f"🏆 En yüksek puan: {top['username']} - {top['total_points']} puan")

        print(f"👥 Toplam kullanıcı sayısı: {total_users}")
        print(f"✨ Leaderboard güncelleme tamamlandı: {datetime.now().isoformat()}")

    except Exception as e:
        print(f"❌ HATA: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
