import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Eksik kafe bildirimleri için servis
/// Kullanıcıların bildirdiği eksik kafeleri CSV formatında saklar
class MissingCafeService {
  final _supabase = Supabase.instance.client;

  /// Eksik kafe bildirimi kaydet
  /// 
  /// Veriler `eksik_kafe_bildirimleri` tablosuna kaydedilir
  /// Admin daha sonra bu verileri CSV olarak export edebilir
  Future<void> reportMissingCafe({
    required String cafeName,
    required double latitude,
    required double longitude,
    String? additionalNotes,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Bildirim yapmak için giriş yapmalısınız');
      }

      // Bildirim kaydı oluştur
      await _supabase.from('eksik_kafe_bildirimleri').insert({
        'kullanici_id': user.id,
        'kafe_adi': cafeName.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'notlar': additionalNotes?.trim(),
        'durum': 'beklemede', // beklemede, inceleniyor, eklendi, reddedildi
      });

      debugPrint('✅ Eksik kafe bildirimi kaydedildi: $cafeName');
    } catch (e) {
      debugPrint('❌ Eksik kafe bildirimi hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcının yaptığı bildirimleri getir
  Future<List<Map<String, dynamic>>> getUserReports() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final data = await _supabase
          .from('eksik_kafe_bildirimleri')
          .select()
          .eq('kullanici_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Bildirimler getirme hatası: $e');
      return [];
    }
  }
}
