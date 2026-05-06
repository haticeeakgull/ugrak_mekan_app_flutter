import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leaderboard Servisi - Puan ve sıralama yönetimi
class LeaderboardService {
  final _supabase = Supabase.instance.client;

  /// Top kullanıcıları getir
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 100}) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, full_name, total_points')
          .gt('total_points', 0)
          .order('total_points', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Leaderboard getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının sırasını getir
  Future<int> getUserRank(String userId) async {
    try {
      final result = await _supabase
          .rpc('get_user_rank', params: {'p_user_id': userId});

      return result as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Sıra getirme hatası: $e');
      return 0;
    }
  }

  /// Kullanıcının puan detaylarını getir
  Future<Map<String, int>> getUserPointBreakdown(String userId) async {
    try {
      final result = await _supabase
          .rpc('get_user_point_breakdown', params: {'p_user_id': userId});

      if (result == null || result.isEmpty) {
        return {
          'post_points': 0,
          'comment_points': 0,
          'like_points': 0,
          'follow_points': 0,
          'badge_points': 0,
          'total_points': 0,
        };
      }

      final data = result[0];
      return {
        'post_points': data['post_points'] ?? 0,
        'comment_points': data['comment_points'] ?? 0,
        'like_points': data['like_points'] ?? 0,
        'follow_points': data['follow_points'] ?? 0,
        'badge_points': data['badge_points'] ?? 0,
        'total_points': data['total_points'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Puan detayı getirme hatası: $e');
      return {
        'post_points': 0,
        'comment_points': 0,
        'like_points': 0,
        'follow_points': 0,
        'badge_points': 0,
        'total_points': 0,
      };
    }
  }

  /// Günlük snapshot'ı getir
  Future<List<Map<String, dynamic>>> getDailySnapshot({
    DateTime? date,
    int limit = 100,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('leaderboard_snapshots')
          .select('''
            rank,
            points,
            profiles!user_id (id, username, avatar_url, full_name)
          ''')
          .eq('snapshot_date', dateStr)
          .order('rank', ascending: true)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Snapshot getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının geçmiş sıralamalarını getir
  Future<List<Map<String, dynamic>>> getUserRankHistory(
    String userId, {
    int days = 30,
  }) async {
    try {
      final response = await _supabase
          .from('leaderboard_snapshots')
          .select('rank, points, snapshot_date')
          .eq('user_id', userId)
          .order('snapshot_date', ascending: false)
          .limit(days);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Sıralama geçmişi getirme hatası: $e');
      return [];
    }
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

      final allUsers = await getLeaderboard(limit: 1000);
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

  /// Bir sonraki güncelleme zamanını hesapla
  DateTime getNextUpdateTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 3, 0);
    return tomorrow;
  }
}
