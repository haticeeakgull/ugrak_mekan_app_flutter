import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import "package:ugrak_mekan_app/views/auth_screen.dart";
import 'package:ugrak_mekan_app/views/main_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    // İlk açılışta kullanıcı varsa OneSignal'e login yap
    _initializeOneSignalForCurrentUser();
  }

  Future<void> _initializeOneSignalForCurrentUser() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && userId != _lastUserId) {
      await _setupOneSignalForUser(userId);
      _lastUserId = userId;
    }
  }

  Future<void> _setupOneSignalForUser(String userId) async {
    try {
      debugPrint('🔔 OneSignal kullanıcı ayarlanıyor: $userId');
      
      // OneSignal'e login ol
      await OneSignal.login(userId);
      
      // Player ID'yi al ve kaydet
      await Future.delayed(const Duration(seconds: 1)); // OneSignal'in hazır olması için bekle
      final playerId = OneSignal.User.pushSubscription.id;
      
      if (playerId != null) {
        debugPrint('📱 Player ID alındı: $playerId');
        
        // Supabase'e kaydet (UPDATE kullan, UPSERT değil)
        await _supabase.from('profiles').update({
          'onesignal_player_id': playerId,
          'notifications_enabled': true,
        }).eq('id', userId);
        
        debugPrint('✅ Player ID Supabase\'e kaydedildi');
      } else {
        debugPrint('⚠️ Player ID henüz hazır değil, tekrar denenecek');
        // 3 saniye sonra tekrar dene
        Future.delayed(const Duration(seconds: 3), () async {
          final retryPlayerId = OneSignal.User.pushSubscription.id;
          if (retryPlayerId != null) {
            await _supabase.from('profiles').update({
              'onesignal_player_id': retryPlayerId,
              'notifications_enabled': true,
            }).eq('id', userId);
            debugPrint('✅ Player ID ikinci denemede kaydedildi: $retryPlayerId');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ OneSignal kullanıcı ayarlama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Supabase'in anlık oturum durumunu dinliyoruz
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Eğer veri henüz gelmediyse yükleme ikonu göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        final userId = session?.user.id;

        // Kullanıcı değiştiyse OneSignal'i güncelle
        if (userId != null && userId != _lastUserId) {
          _setupOneSignalForUser(userId);
          _lastUserId = userId;
        } else if (userId == null && _lastUserId != null) {
          // Çıkış yapıldı
          OneSignal.logout();
          _lastUserId = null;
        }

        // Oturum (session) varsa Ana Sayfaya, yoksa Giriş Ekranına git
        if (session != null) {
          return const MainScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
