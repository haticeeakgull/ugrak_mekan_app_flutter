import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ExploreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cihazın mevcut konumunu al
  Future<Position> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }

  // TÜM ŞEHİRLERİ GETİREN METOD - SADECE MARKER İÇİN GEREKLİ VERİLER
  Future<List<dynamic>> fetchAllKafeler() async {
    try {
      // Sadece marker için gerekli alanları çek (nested select yok)
      final res = await _supabase
          .from('ilce_isimli_kafeler')
          .select('id, kafe_adi, latitude, longitude, il_adi, ilce_adi');
      return res;
    } catch (e) {
      print("fetchKafeler hatası: $e");
      return [];
    }
  }

  // Belirli bir kafe için detaylı bilgi çek (marker tıklandığında)
  Future<Map<String, dynamic>?> fetchKafeDetails(String kafeId) async {
    try {
      final res = await _supabase
          .from('ilce_isimli_kafeler')
          .select('''
            *,
            cafe_gorselleri(foto_url),
            cafe_postlar (
              id,
              baslik,
              icerik,
              created_at,
              profiles (username, avatar_url)
            )
          ''')
          .eq('id', kafeId)
          .single();
      return res;
    } catch (e) {
      print("fetchKafeDetails hatası: $e");
      return null;
    }
  }

  // KEŞFET POSTLARI - OPTİMİZE EDİLMİŞ (20 post, sadece gerekli alanlar)
  Future<List<Map<String, dynamic>>> fetchDiscoveryPostsRaw({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _supabase
          .from('cafe_postlar')
          .select('''
            id,
            baslik,
            icerik,
            foto_url,
            created_at,
            user_id,
            cafe_id,
            profiles (username, avatar_url, is_private),
            ilce_isimli_kafeler (kafe_adi, latitude, longitude)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("fetchDiscoveryPostsRaw hatası: $e");
      return [];
    }
  }

  // ARKADAŞ ARAMA (searchUsers hatasını çözen metod)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .limit(10);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }
}
