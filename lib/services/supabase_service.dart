import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // Dinamik Semt Listesini Çeker
  Future<List<String>> fetchSemtler() async {
    final response = await _client.from('dinamik_semtler').select();

    return (response as List).map((e) => e['semt_adi'].toString()).toList();
  }

  // Dinamik Vibe Etiketlerini Çeker
  Future<List<String>> fetchVibeEtiketleri() async {
    final response = await _client.from('dinamik_vibe_etiketleri').select();
    return (response as List).map((e) => e['etiket_adi'].toString()).toList();
  }
}
