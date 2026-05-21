import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OneSignalNotificationService {
  final _supabase = Supabase.instance.client;
  
  // Navigation key for deep linking
  static GlobalKey<NavigatorState>? navigatorKey;

  // Singleton pattern
  static final OneSignalNotificationService _instance = OneSignalNotificationService._internal();
  factory OneSignalNotificationService() => _instance;
  OneSignalNotificationService._internal();

  // OneSignal'i başlat
  Future<void> initialize(String appId) async {
    try {
      debugPrint('🔔 OneSignal başlatılıyor...');

      // OneSignal'i başlat
      OneSignal.initialize(appId);

      // Bildirim izni iste
      await OneSignal.Notifications.requestPermission(true);

      // Kullanıcı ID'sini ayarla (Supabase user ID)
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await OneSignal.login(userId);
        debugPrint('✅ OneSignal kullanıcı ID ayarlandı: $userId');
      }

      // Player ID'yi al ve Supabase'e kaydet
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null) {
        await _savePlayerID(playerId);
      }

      // Player ID değişikliklerini dinle
      OneSignal.User.pushSubscription.addObserver((state) {
        final newPlayerId = state.current.id;
        if (newPlayerId != null) {
          _savePlayerID(newPlayerId);
        }
      });

      // Bildirim tıklama olaylarını dinle
      OneSignal.Notifications.addClickListener(_handleNotificationClick);

      // Foreground bildirim olaylarını dinle
      OneSignal.Notifications.addForegroundWillDisplayListener(_handleForegroundNotification);

      debugPrint('✅ OneSignal başarıyla başlatıldı');
    } catch (e) {
      debugPrint('❌ OneSignal başlatma hatası: $e');
    }
  }

  // Player ID'yi Supabase'e kaydet
  Future<void> _savePlayerID(String playerId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('profiles').upsert({
        'id': userId,
        'onesignal_player_id': playerId,
        'notifications_enabled': true,
      });

      debugPrint('✅ OneSignal Player ID Supabase\'e kaydedildi: $playerId');
    } catch (e) {
      debugPrint('❌ Player ID kaydetme hatası: $e');
    }
  }

  // Bildirim tıklama olayını işle
  void _handleNotificationClick(OSNotificationClickEvent event) {
    debugPrint('🔔 Bildirime tıklandı');
    
    final data = event.notification.additionalData;
    if (data != null) {
      final type = data['type'] as String?;
      final targetId = data['target_id'] as String?;
      final senderId = data['sender_id'] as String?;

      debugPrint('📬 Bildirim tipi: $type, Target ID: $targetId, Sender ID: $senderId');

      // Navigator key varsa yönlendirme yap
      if (navigatorKey?.currentContext != null) {
        _navigateToScreen(navigatorKey!.currentContext!, type, targetId, senderId);
      }
    }
  }

  // Ekrana yönlendirme
  void _navigateToScreen(BuildContext context, String? type, String? targetId, String? senderId) {
    try {
      switch (type) {
        case 'message':
          // Mesaj bildirimi: chat detay sayfasına git
          if (targetId != null && senderId != null) {
            _navigateToChat(context, targetId, senderId);
          }
          break;
        
        case 'follow':
        case 'like':
        case 'comment':
        case 'notification':
          // Diğer bildirimler: bildirimler sayfasına git
          _navigateToNotifications(context);
          break;
        
        default:
          debugPrint('⚠️ Bilinmeyen bildirim tipi: $type');
      }
    } catch (e) {
      debugPrint('❌ Yönlendirme hatası: $e');
    }
  }

  // Chat sayfasına git
  Future<void> _navigateToChat(BuildContext context, String chatId, String senderId) async {
    try {
      // Gönderen kullanıcının bilgilerini al
      final senderProfile = await _supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .eq('id', senderId)
          .maybeSingle();

      if (senderProfile != null) {
        // Chat detail screen'e git
        Navigator.of(context).pushNamed(
          '/chat_detail',
          arguments: {
            'chatId': chatId,
            'otherUser': senderProfile,
          },
        );
        debugPrint('✅ Chat sayfasına yönlendirildi: $chatId');
      }
    } catch (e) {
      debugPrint('❌ Chat yönlendirme hatası: $e');
    }
  }

  // Bildirimler sayfasına git
  void _navigateToNotifications(BuildContext context) {
    try {
      Navigator.of(context).pushNamed('/notifications');
      debugPrint('✅ Bildirimler sayfasına yönlendirildi');
    } catch (e) {
      debugPrint('❌ Bildirimler yönlendirme hatası: $e');
    }
  }

  // Foreground bildirim olayını işle
  void _handleForegroundNotification(OSNotificationWillDisplayEvent event) {
    debugPrint('📬 Foreground bildirim alındı: ${event.notification.title}');
    
    // Bildirimi göster
    event.notification.display();
  }

  // Bildirimleri aç/kapat
  Future<void> toggleNotifications(bool enabled) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // OneSignal bildirim ayarını değiştir
      if (enabled) {
        await OneSignal.Notifications.requestPermission(true);
      } else {
        // OneSignal'de bildirimleri kapatmak için opt-out yap
        OneSignal.User.pushSubscription.optOut();
      }

      // Supabase'e kaydet
      await _supabase.from('profiles').update({
        'notifications_enabled': enabled,
      }).eq('id', userId);

      debugPrint('✅ Bildirimler ${enabled ? "açıldı" : "kapatıldı"}');
    } catch (e) {
      debugPrint('❌ Bildirim ayarı güncelleme hatası: $e');
    }
  }

  // Kullanıcının bildirim ayarını kontrol et
  Future<bool> areNotificationsEnabled() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('notifications_enabled')
          .eq('id', userId)
          .maybeSingle();

      return response?['notifications_enabled'] ?? true;
    } catch (e) {
      debugPrint('❌ Bildirim ayarı kontrol hatası: $e');
      return true;
    }
  }

  // Player ID'yi temizle (çıkış yaparken)
  Future<void> clearPlayerID() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('profiles').update({
        'onesignal_player_id': null,
      }).eq('id', userId);

      // OneSignal'den çıkış yap
      await OneSignal.logout();

      debugPrint('✅ OneSignal Player ID temizlendi');
    } catch (e) {
      debugPrint('❌ Player ID temizleme hatası: $e');
    }
  }

  // Tag ekle (kullanıcı özelliklerini takip etmek için)
  Future<void> setUserTags(Map<String, String> tags) async {
    try {
      OneSignal.User.addTags(tags);
      debugPrint('✅ OneSignal tags eklendi: $tags');
    } catch (e) {
      debugPrint('❌ Tag ekleme hatası: $e');
    }
  }

  // Tag sil
  Future<void> removeUserTag(String key) async {
    try {
      OneSignal.User.removeTag(key);
      debugPrint('✅ OneSignal tag silindi: $key');
    } catch (e) {
      debugPrint('❌ Tag silme hatası: $e');
    }
  }

  // Bildirim izni durumunu kontrol et
  Future<bool> hasPermission() async {
    try {
      final permission = await OneSignal.Notifications.permission;
      return permission;
    } catch (e) {
      debugPrint('❌ İzin kontrolü hatası: $e');
      return false;
    }
  }

  /// ============================================
  /// PUSH NOTIFICATION GÖNDERME FONKSİYONLARI
  /// ============================================

  /// Push notification gönder (Edge Function üzerinden)
  Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type, // 'message', 'notification', 'follow', 'like', 'comment'
    String? targetId,
    String? senderId,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📬 Push notification gönderiliyor: $userId - $title');

      final response = await _supabase.functions.invoke(
        'send-notification-onesignal',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'target_id': targetId,
          'sender_id': senderId,
          'data': data,
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Push notification başarıyla gönderildi');
        return true;
      } else {
        debugPrint('❌ Push notification hatası: ${response.status}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Push notification gönderme hatası: $e');
      return false;
    }
  }

  /// Takip bildirimi gönder
  Future<void> sendFollowNotification({
    required String followerId,
    required String followedUserId,
    required String followerUsername,
    bool isFollowRequest = false,
  }) async {
    try {
      // 1. Supabase'e bildirim kaydet
      await _supabase.from('notifications').insert({
        'sender_id': followerId,
        'receiver_id': followedUserId,
        'type': isFollowRequest ? 'follow_request' : 'follow',
        'is_read': false,
      });

      // 2. Push notification gönder
      await sendPushNotification(
        userId: followedUserId,
        title: isFollowRequest ? 'Yeni Takip İsteği' : 'Yeni Takipçi',
        body: isFollowRequest
            ? '$followerUsername seni takip etmek istiyor'
            : '$followerUsername seni takip etmeye başladı',
        type: 'follow',
        senderId: followerId,
      );

      debugPrint('✅ Takip bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Takip bildirimi hatası: $e');
    }
  }

  /// Beğeni bildirimi gönder
  Future<void> sendLikeNotification({
    required String likerId,
    required String postOwnerId,
    required String likerUsername,
    required String postId,
  }) async {
    try {
      // Kendi postunu beğenirse bildirim gönderme
      if (likerId == postOwnerId) return;

      // 1. Supabase'e bildirim kaydet
      await _supabase.from('notifications').insert({
        'sender_id': likerId,
        'receiver_id': postOwnerId,
        'type': 'like',
        'post_id': postId,
        'is_read': false,
      });

      // 2. Push notification gönder
      await sendPushNotification(
        userId: postOwnerId,
        title: 'Yeni Beğeni',
        body: '$likerUsername gönderini beğendi',
        type: 'like',
        targetId: postId,
        senderId: likerId,
      );

      debugPrint('✅ Beğeni bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Beğeni bildirimi hatası: $e');
    }
  }

  /// Yorum bildirimi gönder
  Future<void> sendCommentNotification({
    required String commenterId,
    required String postOwnerId,
    required String commenterUsername,
    required String postId,
    required String commentText,
  }) async {
    try {
      // Kendi postuna yorum yaparsa bildirim gönderme
      if (commenterId == postOwnerId) return;

      // 1. Supabase'e bildirim kaydet
      await _supabase.from('notifications').insert({
        'sender_id': commenterId,
        'receiver_id': postOwnerId,
        'type': 'comment',
        'post_id': postId,
        'is_read': false,
      });

      // 2. Push notification gönder
      await sendPushNotification(
        userId: postOwnerId,
        title: 'Yeni Yorum',
        body: '$commenterUsername: ${commentText.length > 50 ? '${commentText.substring(0, 50)}...' : commentText}',
        type: 'comment',
        targetId: postId,
        senderId: commenterId,
      );

      debugPrint('✅ Yorum bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Yorum bildirimi hatası: $e');
    }
  }

  /// Mesaj bildirimi gönder
  Future<void> sendMessageNotification({
    required String senderId,
    required String receiverId,
    required String senderUsername,
    required String messageText,
    required String chatId,
  }) async {
    try {
      // Push notification gönder (Supabase'e kaydetmeye gerek yok, mesaj zaten kaydediliyor)
      await sendPushNotification(
        userId: receiverId,
        title: senderUsername,
        body: messageText.length > 100 ? '${messageText.substring(0, 100)}...' : messageText,
        type: 'message',
        targetId: chatId,
        senderId: senderId,
      );

      debugPrint('✅ Mesaj bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Mesaj bildirimi hatası: $e');
    }
  }
}
