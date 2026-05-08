import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'embedding_service.dart';

class ApiService {
  final _supabase = Supabase.instance.client;
  final _embeddingService = EmbeddingService();

  /// Normal arama - Sadece kafe adına göre (ILIKE)
  Future<List<Cafe>> searchCafesByName(
    String query, {
    String? il,
    String? semt,
    List<String>? vibes, // Artık liste olarak alıyoruz
    double? userLat,
    double? userLng,
  }) async {
    try {
      debugPrint('🔍 Normal arama başladı: "$query"');
      debugPrint('  - il: $il');
      debugPrint('  - semt: $semt');
      debugPrint('  - vibes: $vibes');
      debugPrint('  - userLat: $userLat, userLng: $userLng');
      
      var queryBuilder = _supabase
          .from('ilce_isimli_kafeler')
          .select('''
            id,
            kafe_adi,
            il_adi,
            ilce_adi,
            latitude,
            longitude
          ''');

      // Kafe adına göre arama (case-insensitive)
      if (query.isNotEmpty && query != 'kafe') {
        queryBuilder = queryBuilder.ilike('kafe_adi', '%$query%');
      }

      // Filtreler
      if (il != null && il.isNotEmpty) {
        queryBuilder = queryBuilder.eq('il_adi', il);
      }

      if (semt != null && semt.isNotEmpty) {
        queryBuilder = queryBuilder.eq('ilce_adi', semt);
      }

      // JSONB vibe filtreleme - Supabase'in contains metodu ile sorun var
      // Çözüm: Veri çektikten sonra client-side filtreleme yapacağız
      
      // Limit - Konum varsa daha fazla çek (mesafeye göre sıralayacağız)
      final int limit = (userLat != null && userLng != null) ? 100 : 50;
      
      final List<dynamic> data = await queryBuilder
          .limit(limit)
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Normal arama sonuç sayısı (filtreleme öncesi): ${data.length}');

      // Client-side vibe filtreleme (eğer vibe seçildiyse)
      List<dynamic> filteredData = data;
      if (vibes != null && vibes.isNotEmpty) {
        filteredData = data.where((item) {
          final itemVibes = item['vibe_etiketleri'];
          if (itemVibes == null) return false;
          
          // JSONB array'i Dart list'e çevir
          List<String> cafeVibes = [];
          if (itemVibes is List) {
            cafeVibes = itemVibes.map((v) => v.toString()).toList();
          } else if (itemVibes is String) {
            // Eğer string ise parse et
            try {
              final parsed = jsonDecode(itemVibes);
              if (parsed is List) {
                cafeVibes = parsed.map((v) => v.toString()).toList();
              }
            } catch (_) {}
          }
          
          // Seçilen tüm vibe'lar kafede var mı? (AND mantığı)
          return vibes.every((vibe) => cafeVibes.contains(vibe));
        }).toList();
        
        debugPrint('✅ Vibe filtreleme sonrası: ${filteredData.length} sonuç');
      }

      // Konum varsa mesafeye göre sırala
      if (userLat != null && userLng != null) {
        filteredData.sort((a, b) {
          final distA = _calculateDistance(
            userLat,
            userLng,
            a['latitude'] ?? 0.0,
            a['longitude'] ?? 0.0,
          );
          final distB = _calculateDistance(
            userLat,
            userLng,
            b['latitude'] ?? 0.0,
            b['longitude'] ?? 0.0,
          );
          return distA.compareTo(distB);
        });
        
        debugPrint('✅ Mesafeye göre sıralandı (en yakın: ${filteredData.isNotEmpty ? filteredData.first['kafe_adi'] : 'yok'})');
      } else {
        // Konum yoksa kafe adına göre alfabetik sırala
        filteredData.sort((a, b) {
          final nameA = (a['kafe_adi'] ?? '').toString().toLowerCase();
          final nameB = (b['kafe_adi'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
      }

      // Kolon isimlerini düzelt (il_adi -> il, ilce_adi -> ilce)
      final normalizedData = filteredData.map((item) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        return {
          ...itemMap,
          'il': itemMap['il_adi'],
          'ilce': itemMap['ilce_adi'],
        };
      }).toList();

      return normalizedData.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      debugPrint("❌ Normal arama hatası: $e");
      if (e.toString().contains('invalid input syntax for type json')) {
        debugPrint("💡 Vibe etiketleri formatı hatalı. Array formatında gönderildiğinden emin ol.");
      }
      rethrow;
    }
  }

  /// Basit mesafe hesaplama (Haversine formülü)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// SBERT tabanlı AI kafe araması (Dinamik - 3 tablo birleşik)
  Future<List<Cafe>> searchCafes(
    String query, {
    String? il,
    String? semt,
    List<String>? vibes, // Artık liste olarak alıyoruz
    double? userLat,
    double? userLng,
  }) async {
    try {
      // SBERT API kullan (384 boyutlu)
      final String hfUrl = dotenv.env['SBERT_API_URL'] ?? '';

      if (hfUrl.isEmpty) {
        throw Exception('SBERT_API_URL bulunamadı! .env dosyanı kontrol et.');
      }

      debugPrint('🤖 AI Arama başladı (SBERT 384): "$query"');

      // 🔥 EMBEDDING AL (SBERT - 384 boyutlu)
      final response = await http
          .post(
            Uri.parse(hfUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': query}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Embedding API Hatası: ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      // 🔥 CRITICAL FIX → double list
      final List embedding = (responseData['embedding'] as List)
          .map((e) => e.toDouble())
          .toList();

      debugPrint('📊 Embedding boyutu: ${embedding.length}'); // 384 olmalı

      // 🔥 PARAM TEMİZLEME
      final params = {
        'query_embedding': embedding,
        'search_query': query,
        'match_threshold': 0.0,
        'match_count': 20,
      };

      if (il != null && il.isNotEmpty) {
        params['p_il_adi'] = il;
      }

      if (semt != null && semt.isNotEmpty) {
        params['p_ilce_adi'] = semt;
      }

      if (vibes != null && vibes.isNotEmpty) {
        // JSONB için array gönderiyoruz
        params['p_vibe_etiketleri'] = vibes; // Supabase otomatik olarak JSONB'ye çevirecek
      }

      if (userLat != null && userLng != null) {
        params['p_user_lat'] = userLat;
        params['p_user_lng'] = userLng;
      }

      // 🔥 RPC CALL - Dinamik AI fonksiyonu (3 tablo: kafe + yorumlar + postlar)
      debugPrint('🔍 AI Arama params:');
      debugPrint('  - query: $query');
      debugPrint('  - il: ${params['p_il_adi']}');
      debugPrint('  - ilce: ${params['p_ilce_adi']}');
      debugPrint('  - vibes: ${params['p_vibe_etiketleri']}');
      debugPrint('  - userLat: ${params['p_user_lat']}');
      debugPrint('  - userLng: ${params['p_user_lng']}');
      
      final List<dynamic> data = await _supabase
          .rpc('kafe_ara_ai_dynamic', params: params)
          .timeout(const Duration(seconds: 30));
      
      debugPrint('✅ AI Arama sonuç sayısı: ${data.length}');
      if (data.isNotEmpty) {
        debugPrint('🏆 İlk 3 AI sonuç:');
        for (var item in data.take(3)) {
          final sim = (item['similarity'] as num?)?.toStringAsFixed(3) ?? '0';
          final source = item['match_source'] ?? 'unknown';
          final reason = item['reason'] ?? 'Sebep belirtilmemiş';
          debugPrint('   - ${item['kafe_adi']} (sim: $sim, kaynak: $source)');
          debugPrint('     Sebep: $reason');
        }
      }

      // Çift kayıtları id'ye göre tekilleştir ve similarity'e göre sırala
      final seen = <String>{};
      final unique = data.where((item) {
        final id = item['id'].toString();
        return seen.add(id);
      }).toList();
      
      // Similarity'e göre sırala
      unique.sort((a, b) {
        final simA = (a['similarity'] as num?)?.toDouble() ?? 0.0;
        final simB = (b['similarity'] as num?)?.toDouble() ?? 0.0;
        return simB.compareTo(simA);
      });

      return unique.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      debugPrint("❌ AI Arama Hatası: $e");
      if (e.toString().contains('does not exist') || e.toString().contains('operator')) {
        debugPrint("💡 SQL fonksiyonu güncellenmiş mi? Supabase'de kafe_ara_ai_dynamic fonksiyonunu kontrol et.");
      }
      // Timeout hatası olsa bile boş liste yerine rethrow — çağıran taraf handle eder
      rethrow;
    }
  }

  /// Yorum ekleme (Embedding ile)
  Future<void> addComment(String cafeId, String comment, int rating) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "Yorum yapmak için giriş yapmalısınız!";

      // 1. Yorumu ekle
      final yorumData = await _supabase.from('cafe_yorumlar').insert({
        'cafe_id': cafeId,
        'kullanici_id': user.id,
        'yorum_metni': comment,
        'puan': rating,
      }).select().single();

      debugPrint("✅ Yorum başarıyla eklendi!");

      // 2. Embedding oluştur (arka planda, hata olsa bile devam et)
      final yorumId = yorumData['id'];
      _embeddingService.createYorumEmbedding(yorumId, comment).catchError((e) {
        debugPrint("⚠️ Embedding oluşturulamadı ama yorum kaydedildi: $e");
      });
    } catch (e) {
      debugPrint("Yorum ekleme hatası: $e");
      throw Exception('Yorum gönderilemedi.');
    }
  }

  /// Yorum + Post paylaşımı (Embedding ile)
  Future<void> yorumVePostPaylas({
    required String cafeId,
    required String icerik,
    required bool profilimdePaylas,
    String? fotoUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "İşlem yapmak için giriş yapmalısınız!";

      // 🔥 YORUM
      final yorumData = await _supabase
          .from('cafe_yorumlar')
          .insert({
            'cafe_id': cafeId,
            'kullanici_id': user.id,
            'yorum_metni': icerik,
          })
          .select()
          .single();

      // Yorum için embedding oluştur (arka planda)
      final yorumId = yorumData['id'];
      _embeddingService.createYorumEmbedding(yorumId, icerik).catchError((e) {
        debugPrint("⚠️ Yorum embedding oluşturulamadı: $e");
      });

      // 🔥 POST
      if (profilimdePaylas) {
        final postData = await _supabase.from('cafe_postlar').insert({
          'cafe_id': cafeId,
          'user_id': user.id,
          'yorum_id': yorumData['id'],
          'baslik': 'Yeni Bir Mekan Önerisi!',
          'icerik': icerik,
          'foto_url': fotoUrl,
        }).select().single();

        // Post için embedding oluştur (arka planda)
        final postId = postData['id'];
        _embeddingService.createPostEmbedding(postId, icerik).catchError((e) {
          debugPrint("⚠️ Post embedding oluşturulamadı: $e");
        });
      }
    } catch (e) {
      debugPrint("Paylaşım Hatası: $e");
      rethrow;
    }
  }
}
