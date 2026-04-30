import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Dinamik Embedding Servisi
/// Yeni yorumlar ve postlar için otomatik embedding oluşturur
class EmbeddingService {
  final _supabase = Supabase.instance.client;

  /// Yorum için embedding oluştur ve kaydet
  Future<void> createYorumEmbedding(String yorumId, String yorumMetni) async {
    try {
      debugPrint('🔄 Yorum embedding oluşturuluyor: $yorumId');

      // 1. SBERT API'den embedding al
      final embedding = await _getEmbedding(yorumMetni);

      if (embedding == null) {
        debugPrint('❌ Embedding oluşturulamadı');
        return;
      }

      // 2. Database'e kaydet
      await _supabase
          .from('cafe_yorumlar')
          .update({'embedding': embedding})
          .eq('id', yorumId);

      debugPrint('✅ Yorum embedding kaydedildi: $yorumId');
    } catch (e) {
      debugPrint('❌ Yorum embedding hatası: $e');
      // Hata olsa bile devam et (embedding opsiyonel)
    }
  }

  /// Post için embedding oluştur ve kaydet
  Future<void> createPostEmbedding(String postId, String postIcerik) async {
    try {
      debugPrint('🔄 Post embedding oluşturuluyor: $postId');

      // 1. SBERT API'den embedding al
      final embedding = await _getEmbedding(postIcerik);

      if (embedding == null) {
        debugPrint('❌ Embedding oluşturulamadı');
        return;
      }

      // 2. Database'e kaydet
      await _supabase
          .from('cafe_postlar')
          .update({'embedding': embedding})
          .eq('id', postId);

      debugPrint('✅ Post embedding kaydedildi: $postId');
    } catch (e) {
      debugPrint('❌ Post embedding hatası: $e');
      // Hata olsa bile devam et (embedding opsiyonel)
    }
  }



  /// SBERT API'den embedding al (384 boyutlu)
  Future<List<double>?> _getEmbedding(String text) async {
    try {
      // SBERT API kullan (384 boyutlu)
      final String hfUrl = dotenv.env['SBERT_API_URL'] ?? '';

      if (hfUrl.isEmpty) {
        debugPrint('❌ SBERT_API_URL bulunamadı!');
        return null;
      }

      // Boş veya çok kısa metinler için embedding oluşturma
      if (text.trim().isEmpty || text.trim().length < 3) {
        debugPrint('⚠️ Metin çok kısa, embedding oluşturulmadı');
        return null;
      }

      final response = await http
          .post(
            Uri.parse(hfUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('❌ Embedding API Hatası: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List embedding = (responseData['embedding'] as List)
          .map((e) => e.toDouble())
          .toList();

      debugPrint('📊 Embedding boyutu: ${embedding.length}'); // 384 olmalı

      return embedding.cast<double>();
    } catch (e) {
      debugPrint('❌ Embedding alma hatası: $e');
      return null;
    }
  }

  /// Toplu embedding oluşturma (mevcut veriler için)
  /// Sadece yorumlar ve postlar için - Google Maps embedding_v2 zaten mevcut
  Future<void> createBulkEmbeddings({
    bool processYorumlar = true,
    bool processPostlar = true,
    int batchSize = 10,
  }) async {
    try {
      debugPrint('🔄 Toplu embedding oluşturma başladı...');
      debugPrint('📊 Batch size: $batchSize');

      if (processYorumlar) {
        await _processBulkYorumlar(batchSize);
      }

      if (processPostlar) {
        await _processBulkPostlar(batchSize);
      }

      debugPrint('✅ Toplu embedding oluşturma tamamlandı!');
    } catch (e) {
      debugPrint('❌ Toplu embedding hatası: $e');
    }
  }

  Future<void> _processBulkYorumlar(int batchSize) async {
    debugPrint('📝 Yorumlar işleniyor...');

    // Embedding'i olmayan yorumları çek
    final yorumlar = await _supabase
        .from('cafe_yorumlar')
        .select('id, yorum_metni')
        .isFilter('embedding', null)
        .limit(batchSize);

    debugPrint('📊 ${yorumlar.length} yorum bulundu');

    for (var yorum in yorumlar) {
      final id = yorum['id'];
      final metin = yorum['yorum_metni'] ?? '';

      if (metin.isNotEmpty) {
        await createYorumEmbedding(id, metin);
        // API rate limit için kısa bekleme
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _processBulkPostlar(int batchSize) async {
    debugPrint('📝 Postlar işleniyor...');

    // Embedding'i olmayan postları çek
    final postlar = await _supabase
        .from('cafe_postlar')
        .select('id, icerik, baslik')
        .isFilter('embedding', null)
        .limit(batchSize);

    debugPrint('📊 ${postlar.length} post bulundu');

    for (var post in postlar) {
      final id = post['id'];
      final baslik = post['baslik'] ?? '';
      final icerik = post['icerik'] ?? '';
      final metin = '$baslik $icerik'.trim();

      if (metin.isNotEmpty) {
        await createPostEmbedding(id, metin);
        // API rate limit için kısa bekleme
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
}
