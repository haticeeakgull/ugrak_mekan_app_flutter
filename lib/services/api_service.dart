import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final _supabase = Supabase.instance.client;

  /// SBERT tabanlı kafe araması
  Future<List<Cafe>> searchCafes(
    String query, {
    String? il,
    String? semt,
    String? vibe,
    double? userLat,
    double? userLng,
  }) async {
    try {
      final String hfUrl = dotenv.env['SBERT_API_URL'] ?? '';

      if (hfUrl.isEmpty) {
        throw Exception('SBERT_API_URL bulunamadı! .env dosyanı kontrol et.');
      }

      // 🔥 EMBEDDING AL
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

      // 🔥 PARAM TEMİZLEME
      final params = {
        'query_embedding': embedding,
        'search_query': query,
        'match_threshold': 0.05,
        'match_count': 10,
      };

      if (il != null && il.isNotEmpty) {
        params['p_il_adi'] = il;
      }

      if (semt != null && semt.isNotEmpty) {
        params['p_ilce_adi'] = semt;
      }

      if (vibe != null && vibe.isNotEmpty) {
        params['p_vibe_etiketi'] = vibe;
      }

      if (userLat != null && userLng != null) {
        params['p_user_lat'] = userLat;
        params['p_user_lng'] = userLng;
      }

      // 🔥 RPC CALL
      final List<dynamic> data = await _supabase
          .rpc('kafe_ara_v6', params: params)
          .timeout(const Duration(seconds: 30));

      return data.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      print("ApiService Arama Hatası: $e");
      // Timeout hatası olsa bile boş liste yerine rethrow — çağıran taraf handle eder
      rethrow;
    }
  }

  /// Yorum ekleme
  Future<void> addComment(String cafeId, String comment, int rating) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "Yorum yapmak için giriş yapmalısınız!";

      await _supabase.from('cafe_yorumlar').insert({
        'cafe_id': cafeId,
        'kullanici_id': user.id,
        'yorum_metni': comment,
        'puan': rating,
      });

      print("Yorum başarıyla eklendi!");
    } catch (e) {
      print("Yorum ekleme hatası: $e");
      throw Exception('Yorum gönderilemedi.');
    }
  }

  /// Yorum + Post paylaşımı
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

      // 🔥 POST
      if (profilimdePaylas) {
        await _supabase.from('cafe_postlar').insert({
          'cafe_id': cafeId,
          'user_id': user.id,
          'yorum_id': yorumData['id'],
          'baslik': 'Yeni Bir Mekan Önerisi!',
          'icerik': icerik,
          'foto_url': fotoUrl,
        });
      }
    } catch (e) {
      print("Paylaşım Hatası: $e");
      rethrow;
    }
  }
}
