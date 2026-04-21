-- ============================================
-- SUPABASE PERFORMANS İYİLEŞTİRME İNDEKSLERİ
-- ============================================
-- Bu indeksleri Supabase SQL Editor'de çalıştır

-- 1. Discovery Posts için created_at indeksi
-- (ORDER BY created_at DESC sorgularını hızlandırır)
CREATE INDEX IF NOT EXISTS idx_cafe_postlar_created_at 
ON cafe_postlar(created_at DESC);

-- 2. Cafe ID ile post aramaları için
CREATE INDEX IF NOT EXISTS idx_cafe_postlar_cafe_id 
ON cafe_postlar(cafe_id);

-- 3. User ID ile post aramaları için
CREATE INDEX IF NOT EXISTS idx_cafe_postlar_user_id 
ON cafe_postlar(user_id);

-- 4. Kafe görselleri için cafe_id indeksi
CREATE INDEX IF NOT EXISTS idx_cafe_gorselleri_cafe_id 
ON cafe_gorselleri(cafe_id);

-- 5. Kafe yorumları için cafe_id indeksi
CREATE INDEX IF NOT EXISTS idx_cafe_yorumlar_cafe_id 
ON cafe_yorumlar(cafe_id);

-- 6. İl bazlı kafe aramaları için
CREATE INDEX IF NOT EXISTS idx_kafeler_il_adi 
ON ilce_isimli_kafeler(il_adi);

-- 7. İlçe bazlı kafe aramaları için
CREATE INDEX IF NOT EXISTS idx_kafeler_ilce_adi 
ON ilce_isimli_kafeler(ilce_adi);

-- 8. Profiles için username aramaları (ILIKE için)
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower 
ON profiles(LOWER(username));

-- ============================================
-- OPSİYONEL: PostGIS ile Konum Bazlı Sorgular
-- ============================================
-- Not: PostGIS extension'ı aktif olmalı
-- Supabase'de: Database > Extensions > postgis'i enable et

-- PostGIS extension'ı kontrol et
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- Konum bazlı sorgular için GIST indeksi
-- CREATE INDEX IF NOT EXISTS idx_kafeler_location 
-- ON ilce_isimli_kafeler 
-- USING GIST (ST_MakePoint(longitude, latitude));

-- ============================================
-- PERFORMANS ANALİZİ
-- ============================================
-- Sorgu performansını test etmek için:

-- EXPLAIN ANALYZE
-- SELECT id, baslik, icerik, created_at
-- FROM cafe_postlar
-- ORDER BY created_at DESC
-- LIMIT 20;

-- ============================================
-- İNDEKS KULLANIM İSTATİSTİKLERİ
-- ============================================
-- İndekslerin kullanılıp kullanılmadığını kontrol et:

-- SELECT 
--   schemaname,
--   tablename,
--   indexname,
--   idx_scan as index_scans,
--   idx_tup_read as tuples_read,
--   idx_tup_fetch as tuples_fetched
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY idx_scan DESC;

-- ============================================
-- VACUUM VE ANALYZE
-- ============================================
-- İndeksler oluşturduktan sonra çalıştır:

-- VACUUM ANALYZE cafe_postlar;
-- VACUUM ANALYZE ilce_isimli_kafeler;
-- VACUUM ANALYZE profiles;
-- VACUUM ANALYZE cafe_gorselleri;
-- VACUUM ANALYZE cafe_yorumlar;

-- ============================================
-- BEKLENEN PERFORMANS İYİLEŞMESİ
-- ============================================
-- 
-- 1. Discovery posts sorgusu: 3-5x daha hızlı
-- 2. Kafe aramaları: 2-3x daha hızlı
-- 3. User aramaları: 4-6x daha hızlı
-- 4. Join işlemleri: 2-4x daha hızlı
--
-- Toplam beklenen iyileşme: %60-80 daha hızlı sorgular
