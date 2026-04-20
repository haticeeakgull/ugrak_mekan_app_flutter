import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ExploreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Position> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }

  Future<List<dynamic>> fetchKafeler(LatLngBounds bounds) async {
    return await _supabase
        .from('ilce_isimli_kafeler')
        .select('''
          *,
          cafe_gorselleri(*),
          cafe_postlar (
            *,
            profiles (*)
          )
        ''')
        .gte('latitude', bounds.southwest.latitude)
        .lte('latitude', bounds.northeast.latitude)
        .gte('longitude', bounds.southwest.longitude)
        .lte('longitude', bounds.northeast.longitude)
        .limit(300);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await _supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(8);
    return List<Map<String, dynamic>>.from(res);
  }
}
