import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leaderboard Servisi - Haftalık puan ve sıralama yönetimi
class LeaderboardService {
  final _supabase = Supabase.instance.client;

  /// Haftalık leaderboard'u getir (Bu haftanın liderleri)
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 100}) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, full_name, weekly_points')
          .gt('weekly_points', 0)
          .order('weekly_points', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Haftalık leaderboard getirme hatası: $e');
      return [];
    }
  }

  /// Geçmiş hafta kazananlarını getir
  Future<List<Map<String, dynamic>>> getPastWinners({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('weekly_leaderboard_winners')
          .select('*')
          .order('week_start_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Geçmiş kazananlar getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının haftalık sırasını getir
  Future<int> getUserRank(String userId) async {
    try {
      // Haftalık puanlara göre sıralama
      final allUsers = await getWeeklyLeaderboard(limit: 1000);
      
      // Kullanıcıyı bul
      final userIndex = allUsers.indexWhere((user) => user['id'] == userId);
      
      // Bulunamadıysa veya puanı 0 ise
      if (userIndex == -1) {
        // Kullanıcının puanını kontrol et
        final userProfile = await _supabase
            .from('profiles')
            .select('weekly_points')
            .eq('id', userId)
            .maybeSingle();
        
        // Puanı 0 ise sıralama yok
        if (userProfile == null || userProfile['weekly_points'] == 0) {
          return 0;
        }
        
        // Puanı var ama listede yok (limit dışında)
        return 999; // Sıralama dışı
      }
      
      return userIndex + 1;
    } catch (e) {
      debugPrint('❌ Sıra getirme hatası: $e');
      return 0;
    }
  }

  /// Kullanıcının haftalık puan detaylarını getir
  Future<Map<String, int>> getUserWeeklyBreakdown(String userId) async {
    try {
      // Haftalık puan dökümü için RPC fonksiyonu çağır
      // Not: Bu fonksiyonu SQL'de oluşturmanız gerekiyor
      final result = await _supabase
          .rpc('get_user_weekly_breakdown', params: {'p_user_id': userId});

      if (result == null || result.isEmpty) {
        return {
          'post_points': 0,
          'comment_points': 0,
          'like_points': 0,
          'follower_points': 0,
          'badge_points': 0,
          'total_points': 0,
        };
      }

      final data = result[0];
      return {
        'post_points': data['post_points'] ?? 0,
        'comment_points': data['comment_points'] ?? 0,
        'like_points': data['like_points'] ?? 0,
        'follower_points': data['follower_points'] ?? 0,
        'badge_points': data['badge_points'] ?? 0,
        'total_points': data['total_points'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Haftalık puan detayı getirme hatası: $e');
      return {
        'post_points': 0,
        'comment_points': 0,
        'like_points': 0,
        'follower_points': 0,
        'badge_points': 0,
        'total_points': 0,
      };
    }
  }

  /// Bu haftanın başlangıç ve bitiş tarihlerini getir
  Map<String, DateTime> getCurrentWeekDates() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Pazartesi, 7 = Pazar
    
    // Pazartesi 00:00
    final weekStart = now.subtract(Duration(
      days: weekday - 1,
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    ));
    
    // Pazar 23:59
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    return {
      'start': weekStart,
      'end': weekEnd,
    };
  }

  /// Haftanın kalan gün sayısını getir
  int getDaysUntilReset() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Pazartesi, 7 = Pazar
    return 7 - weekday + 1; // Pazara kadar kalan gün
  }

  /// Kullanıcının çevresindeki sıralamayı getir (±5)
  Future<List<Map<String, dynamic>>> getUserNeighborhood(
    String userId,
  ) async {
    try {
      // Önce kullanıcının sırasını al
      final rank = await getUserRank(userId);
      if (rank == 0) return [];

      // Sıranın ±5 aralığındaki kullanıcıları getir
      final startRank = (rank - 5).clamp(1, double.infinity).toInt();
      final endRank = rank + 5;

      final allUsers = await getWeeklyLeaderboard(limit: 1000);
      return allUsers
          .where((user) {
            final index = allUsers.indexOf(user) + 1;
            return index >= startRank && index <= endRank;
          })
          .toList();
    } catch (e) {
      debugPrint('❌ Çevre sıralama getirme hatası: $e');
      return [];
    }
  }

  /// Son güncelleme zamanını getir
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('last_points_update')
          .not('last_points_update', 'is', null)
          .order('last_points_update', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return DateTime.parse(response['last_points_update']);
    } catch (e) {
      debugPrint('❌ Son güncelleme zamanı getirme hatası: $e');
      return null;
    }
  }

  /// Bir sonraki güncelleme zamanını hesapla (Her gün 03:00)
  DateTime getNextUpdateTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 3, 0);
    return tomorrow;
  }

  /// Bir sonraki haftalık sıfırlama zamanını hesapla (Pazar 23:59)
  DateTime getNextResetTime() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Pazartesi, 7 = Pazar
    final daysUntilSunday = 7 - weekday;
    
    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      23,
      59,
      59,
    );
    
    return nextSunday;
  }
}
