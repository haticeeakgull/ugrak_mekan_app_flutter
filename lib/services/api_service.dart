import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final _supabase = Supabase.instance.client;

  /// BERT tabanlı kafe araması yapar
  Future<List<Cafe>> searchCafes(
    String query, {
    String? semt,
    String? vibe,
  }) async {
    try {
      final String hfUrl = dotenv.env['BERT_API_URL'] ?? '';

      if (hfUrl.isEmpty) {
        throw Exception(
          'BERT_API_URL bulunamadı! .env dosyanızı kontrol edin.',
        );
      }

      final response = await http.post(
        Uri.parse(hfUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': query}),
      );

      if (response.statusCode != 200) {
        print("Hata Kodu: ${response.statusCode}");
        print("Hata Mesajı: ${response.body}");
        throw Exception('BERT API Hatası');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> embedding = responseData['embedding'];

      // 2. Supabase RPC Çağrısı
      final List<dynamic> data = await _supabase.rpc(
        'kafe_ara_v6',
        params: {
          'search_query': query,
          'query_embedding': embedding,
          'p_ilce_adi': semt,
          'p_vibe_etiketi': vibe,
          'match_threshold': 0.1,
          'match_count': 10,
        },
      );

      return data.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      print("ApiService Arama Hatası: $e");
      rethrow;
    }
  }

  /// Sadece yorum ekler (kullanici_adi artık gönderilmiyor)
  Future<void> addComment(String cafeId, String comment, int rating) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "Yorum yapmak için giriş yapmalısınız!";

      await _supabase.from('cafe_yorumlar').insert({
        'cafe_id': cafeId,
        'kullanici_id': user.id, // Foreign Key bağlantısı
        'yorum_metni': comment,
        'puan': rating,
      });
      print("Yorum başarıyla eklendi!");
    } catch (e) {
      print("Yorum ekleme hatası: $e");
      throw Exception('Yorum gönderilemedi, lütfen tekrar deneyin.');
    }
  }

  /// Hem yorum ekler hem de isteğe bağlı olarak post (öneri) paylaşır
  Future<void> yorumVePostPaylas({
    required String cafeId,
    required String icerik,
    required bool profilimdePaylas,
    String? fotoUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "İşlem yapmak için giriş yapmalısınız!";

      // 1. Önce Yorumu Kaydet
      final yorumData = await _supabase
          .from('cafe_yorumlar')
          .insert({
            'cafe_id': cafeId,
            'kullanici_id': user.id,
            'yorum_metni': icerik,
          })
          .select()
          .single();

      // 2. Eğer kullanıcı "Profilimde Paylaş" dediyse Post tablosuna da ekle
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
