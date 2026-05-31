import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/services/onesignal_notification_service.dart';

class FollowService {
  final _supabase = Supabase.instance.client;
  final _notificationService = OneSignalNotificationService();

  // Takip durumunu kontrol et
  Future<String> getFollowStatus(String followerId, String followingId) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('status')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return res != null ? res['status'] : "none";
    } catch (e) {
      return "none";
    }
  }

  // Takip et veya İstek gönder (DÜZELTİLDİ)
  Future<void> followUser({
    required String myId,
    required String targetId,
    required bool isPrivate,
  }) async {
    // 1. Hesap gizliliğine göre durumu belirle
    String newStatus = isPrivate ? "pending" : "following";

    // 2. 'follows' tablosuna kaydı ekle
    await _supabase.from('follows').insert({
      'follower_id': myId,
      'following_id': targetId,
      'status': newStatus,
    });

    // 3. Eğer takip onaylandıysa (gizli hesap değilse), takip edilen kişiye puan ekle
    if (!isPrivate) {
      await _addFollowerPoints(targetId);
    }

    // 4. Kullanıcı bilgilerini al
    final myProfile = await _supabase
        .from('profiles')
        .select('username')
        .eq('id', myId)
        .single();

    // 5. Bildirim gönder (Supabase + Push Notification)
    await _notificationService.sendFollowNotification(
      followerId: myId,
      followedUserId: targetId,
      followerUsername: myProfile['username'] ?? 'Bir kullanıcı',
      isFollowRequest: isPrivate,
    );
  }

  // Takipçi puanı ekle (5 puan)
  Future<void> _addFollowerPoints(String userId) async {
    try {
      // Mevcut puanları al
      final profile = await _supabase
          .from('profiles')
          .select('weekly_points')
          .eq('id', userId)
          .single();

      final currentPoints = profile['weekly_points'] ?? 0;
      final newPoints = currentPoints + 5;

      // Puanı güncelle
      await _supabase
          .from('profiles')
          .update({'weekly_points': newPoints})
          .eq('id', userId);

      debugPrint('✅ Takipçi puanı eklendi: +5 puan (Toplam: $newPoints)');
    } catch (e) {
      debugPrint('❌ Takipçi puanı ekleme hatası: $e');
    }
  }

  // Takibi bırak veya İsteği iptal et
  Future<void> unfollowUser(String myId, String targetId) async {
    // Önce takip durumunu kontrol et
    final followRecord = await _supabase
        .from('follows')
        .select('status')
        .eq('follower_id', myId)
        .eq('following_id', targetId)
        .maybeSingle();

    // Eğer takip durumu 'following' ise puan düşür
    if (followRecord != null && followRecord['status'] == 'following') {
      await _removeFollowerPoints(targetId);
    }

    // Takibi sil
    await _supabase.from('follows').delete().match({
      'follower_id': myId,
      'following_id': targetId,
    });

    // Opsiyonel: Takibi bıraktığında eski bildirimleri de silebilirsin
    // await _supabase.from('notifications').delete().match({
    //   'sender_id': myId,
    //   'receiver_id': targetId,
    //   'type': 'follow_request'
    // });
  }

  // Takipçi puanını düşür (5 puan)
  Future<void> _removeFollowerPoints(String userId) async {
    try {
      // Mevcut puanları al
      final profile = await _supabase
          .from('profiles')
          .select('weekly_points')
          .eq('id', userId)
          .single();

      final currentPoints = profile['weekly_points'] ?? 0;
      final newPoints = (currentPoints - 5).clamp(0, double.infinity).toInt();

      // Puanı güncelle
      await _supabase
          .from('profiles')
          .update({'weekly_points': newPoints})
          .eq('id', userId);

      debugPrint('✅ Takipçi puanı düşürüldü: -5 puan (Toplam: $newPoints)');
    } catch (e) {
      debugPrint('❌ Takipçi puanı düşürme hatası: $e');
    }
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
