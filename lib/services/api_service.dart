import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';

class ApiService {
  final _supabase = Supabase.instance.client;

  Future<List<Cafe>> searchCafes(String query) async {
    try {
      // 1. BERT Vektörünü Al (FastAPI)
      // Emülatör kullandığın için 10.0.2.2 kullanmaya devam!
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/embed'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': query}),
      );

      if (response.statusCode != 200) throw Exception('BERT API Hatası');

      final List<dynamic> embedding = jsonDecode(response.body)['embedding'];

      // 2. Supabase RPC Çağrısı
      final List<dynamic> data = await _supabase.rpc(
        'kafe_ara_v4',
        params: {
          'search_query': query,
          'query_embedding': embedding,
          'match_threshold': 0.2,
          'match_count': 5,
        },
      );

      // JSON listesini Cafe nesneleri listesine çeviriyoruz
      return data.map((item) => Cafe.fromJson(item)).toList();
    } catch (e) {
      print("Hata oluştu: $e");
      rethrow;
    }
  }
}
