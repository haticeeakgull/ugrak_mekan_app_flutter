import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';

class ApiService {
  final _supabase = Supabase.instance.client;

  // Parametreleri opsiyonel ({String? semt, String? vibe}) olarak ekledik
  Future<List<Cafe>> searchCafes(
    String query, {
    String? semt,
    String? vibe,
  }) async {
    try {
      // 1. BERT Vektörünü Al (FastAPI)
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/embed'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': query}),
      );

      if (response.statusCode != 200) throw Exception('BERT API Hatası');

      final List<dynamic> embedding = jsonDecode(response.body)['embedding'];

      // 2. Supabase RPC Çağrısı (v5)
      // SQL fonksiyonundaki parametre isimleriyle (p_ilce_adi, p_vibe_etiketi)
      // birebir aynı anahtarları kullanıyoruz.
      final List<dynamic> data = await _supabase.rpc(
        'kafe_ara_v5',
        params: {
          'search_query': query,
          'query_embedding': embedding,
          'p_ilce_adi': semt, // HomeScreen'den gelen secilenSemt
          'p_vibe_etiketi': vibe, // HomeScreen'den gelen secilenVibe
          'match_threshold': 0.1,
          'match_count': 10, // Sonuç sayısını isteğe bağlı artırabilirsin
        },
      );

      // JSON listesini Cafe nesneleri listesine çeviriyoruz
      return data.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      print("ApiService Hatası: $e");
      rethrow;
    }
  }

  Future<void> addComment(String cafeId, String comment, int rating) async {
    try {
      await _supabase.from('cafe_yorumlar').insert({
        'cafe_id': cafeId,
        'yorum_metni': comment,
        'kullanici_adi': 'Misafir Kullanıcı',
        'puan': rating,
      });
      print("Yorum başarıyla eklendi!");
    } catch (e) {
      print("Yorum ekleme hatası: $e");
      // Hatayı yukarı fırlatarak UI tarafında kullanıcıya gösterilmesini sağlayabilirsin
      throw Exception('Yorum gönderilemedi, lütfen tekrar deneyin.');
    }
  }

  Future<void> yorumVePostPaylas({
    required String cafeId,
    required String icerik,
    required bool profilimdePaylas,
    String? fotoUrl,
  }) async {
    // 1. Önce Yorumu Kaydet
    final yorumData = await _supabase
        .from('cafe_yorumlar')
        .insert({
          'cafe_id': cafeId,
          'yorum_metni': icerik,
          'kullanici_adi': 'Misafir Kullanıcı',
        })
        .select()
        .single(); // Eklenen yorumun ID'sini almak için .select().single()

    // 2. Eğer kullanıcı "Profilimde Paylaş" dediyse Post tablosuna da ekle
    if (profilimdePaylas) {
      await _supabase.from('cafe_postlar').insert({
        'cafe_id': cafeId,
        'yorum_id': yorumData['id'], // Yorumla postu bağlıyoruz
        'kullanici_adi': 'Misafir Kullanıcı',
        'baslik': 'Yeni Bir Mekan Önerisi!',
        'icerik': icerik,
        'foto_url': fotoUrl,
      });
    }
  }
}
