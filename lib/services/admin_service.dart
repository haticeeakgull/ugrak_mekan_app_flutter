import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Admin servisi - Admin kontrolü ve yetkilendirme
class AdminService {
  final _supabase = Supabase.instance.client;

  /// Admin email'i .env dosyasından al
  List<String> get adminEmails {
    final adminEmail = dotenv.env['ADMIN_EMAIL'];
    if (adminEmail == null || adminEmail.isEmpty) {
      debugPrint('⚠️ ADMIN_EMAIL .env dosyasında bulunamadı!');
      return [];
    }
    
    // Virgülle ayrılmış birden fazla email destekle
    // Örnek: ADMIN_EMAIL=admin1@example.com,admin2@example.com
    return adminEmail
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Kullanıcının admin olup olmadığını kontrol et
  Future<bool> isAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final email = user.email;
      if (email == null) return false;

      // Email listesinde var mı kontrol et
      final admins = adminEmails;
      final isAdminUser = admins.contains(email.toLowerCase());
      
      if (isAdminUser) {
        debugPrint('✅ Admin kullanıcı: $email');
      }
      
      return isAdminUser;
    } catch (e) {
      debugPrint('❌ Admin kontrolü hatası: $e');
      return false;
    }
  }

  /// Admin paneline erişim kontrolü
  Future<bool> canAccessAdminPanel() async {
    return await isAdmin();
  }

  /// Bildirimleri getir (admin için RLS bypass)
  Future<List<Map<String, dynamic>>> getBildirimler({
    String? durum,
  }) async {
    try {
      var query = _supabase
          .from('eksik_kafe_bildirimleri')
          .select('*, profiles!kullanici_id(email, username)');

      if (durum != null) {
        query = query.eq('durum', durum);
      }

      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Bildirimler getirme hatası: $e');
      rethrow;
    }
  }

  /// Bildirim durumunu güncelle
  Future<void> updateBildirimDurum(String id, String yeniDurum) async {
    try {
      await _supabase
          .from('eksik_kafe_bildirimleri')
          .update({'durum': yeniDurum})
          .eq('id', id);

      debugPrint('✅ Bildirim durumu güncellendi: $id -> $yeniDurum');
    } catch (e) {
      debugPrint('❌ Durum güncelleme hatası: $e');
      rethrow;
    }
  }

  /// İstatistikleri getir
  Future<Map<String, int>> getIstatistikler() async {
    try {
      final data = await _supabase
          .from('eksik_kafe_bildirimleri')
          .select('durum');

      final stats = <String, int>{
        'beklemede': 0,
        'inceleniyor': 0,
        'eklendi': 0,
        'reddedildi': 0,
      };

      for (var item in data) {
        final durum = item['durum'] as String;
        stats[durum] = (stats[durum] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ İstatistik hatası: $e');
      return {};
    }
  }
}
