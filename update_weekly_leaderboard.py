#!/usr/bin/env python3
"""
Weekly Leaderboard Update Script
Bu script GitHub Actions tarafından çalıştırılır:
1. Her gün: Haftalık puanları günceller
2. Her Pazar: Kazananı kaydeder ve puanları sıfırlar
"""

import os
import sys
import argparse
from datetime import datetime
from supabase import create_client, Client


def update_weekly_points(supabase: Client):
    """Tüm kullanıcıların haftalık puanlarını güncelle"""
    print("📊 Haftalık puanlar hesaplanıyor...")

    try:
        result = supabase.rpc("update_all_weekly_points").execute()
        print("✅ Haftalık puanlar güncellendi")

        # İstatistikleri göster
        top_users = (
            supabase.from_("profiles")
            .select("username, weekly_points")
            .order("weekly_points", desc=True)
            .limit(5)
            .execute()
        )

        if top_users.data:
            print("\n🏆 Bu haftanın liderleri:")
            for i, user in enumerate(top_users.data, 1):
                print(f"   {i}. {user['username']} - {user['weekly_points']} puan")

        return True
    except Exception as e:
        print(f"❌ Haftalık puan güncelleme hatası: {str(e)}")
        return False


def save_winner_and_reset(supabase: Client):
    """Hafta kazananını kaydet ve puanları sıfırla"""
    print("🏆 Hafta kazananı kaydediliyor ve puanlar sıfırlanıyor...")

    try:
        # Önce kazananı göster
        winner = (
            supabase.from_("profiles")
            .select("username, weekly_points")
            .order("weekly_points", desc=True)
            .limit(1)
            .execute()
        )

        if winner.data and len(winner.data) > 0:
            w = winner.data[0]
            print(
                f"\n🎉 Bu haftanın kazananı: {w['username']} - {w['weekly_points']} puan"
            )

        # Kazananı kaydet ve sıfırla
        result = supabase.rpc("save_weekly_winner_and_reset").execute()
        print("✅ Kazanan kaydedildi ve puanlar sıfırlandı")
        print("🔄 Yeni hafta başladı! Herkesin puanı 0'dan başlıyor.")

        return True
    except Exception as e:
        print(f"❌ Kazanan kaydetme hatası: {str(e)}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Weekly Leaderboard Update")
    parser.add_argument(
        "--action",
        choices=["update", "reset"],
        required=True,
        help="Action to perform: update (daily) or reset (weekly)",
    )
    args = parser.parse_args()

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

    print(f"🚀 Haftalık leaderboard işlemi başladı: {datetime.now().isoformat()}")
    print(f"📋 İşlem: {args.action}")

    success = False

    if args.action == "update":
        # Günlük: Haftalık puanları güncelle
        success = update_weekly_points(supabase)
    elif args.action == "reset":
        # Haftalık: Kazananı kaydet ve sıfırla
        success = save_winner_and_reset(supabase)

    if success:
        print(f"✨ İşlem tamamlandı: {datetime.now().isoformat()}")
        sys.exit(0)
    else:
        print(f"❌ İşlem başarısız: {datetime.now().isoformat()}")
        sys.exit(1)


if __name__ == "__main__":
    main()
