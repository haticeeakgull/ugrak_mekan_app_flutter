import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OneSignalNotificationService {
  final _supabase = Supabase.instance.client;

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

      debugPrint('📬 Bildirim tipi: $type, Target ID: $targetId');

      // Yönlendirme yapılabilir (Navigator kullanarak)
      // Örnek: Navigator.pushNamed(context, '/chat', arguments: targetId);
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
}
