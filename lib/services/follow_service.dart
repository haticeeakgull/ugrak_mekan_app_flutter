import 'package:supabase_flutter/supabase_flutter.dart';

class FollowService {
  final _supabase = Supabase.instance.client;

  // Takip durumunu kontrol et
  Future<String> getFollowStatus(String followerId, String followingId) async {
    final res = await _supabase
        .from('follows')
        .select('status')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();

    return res != null ? res['status'] : "none";
  }

  // Takip et veya İstek gönder
  Future<void> followUser({
    required String myId,
    required String targetId,
    required bool isPrivate,
  }) async {
    String newStatus = isPrivate ? "pending" : "following";

    await _supabase.from('follows').insert({
      'follower_id': myId,
      'following_id': targetId,
      'status': newStatus,
    });

    // Bildirim gönder
    await _supabase.from('notifications').insert({
      'sender_id': myId,
      'receiver_id': targetId,
      'type': isPrivate ? 'follow_request' : 'follow_accept',
    });
  }

  // Takibi bırak veya İsteği iptal et
  Future<void> unfollowUser(String myId, String targetId) async {
    await _supabase.from('follows').delete().match({
      'follower_id': myId,
      'following_id': targetId,
    });
  }

  // Takipçileri getir
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final response = await _supabase
        .from('follows')
        .select(
          'follower_id, profiles!follower_id(id, username, full_name, avatar_url)',
        )
        .eq('following_id', userId)
        .eq('status', 'following');
    return List<Map<String, dynamic>>.from(response);
  }

  // Takip edilenleri getir
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final response = await _supabase
        .from('follows')
        .select(
          'following_id, profiles!following_id(id, username, full_name, avatar_url)',
        )
        .eq('follower_id', userId)
        .eq('status', 'following');
    return List<Map<String, dynamic>>.from(response);
  }
}
