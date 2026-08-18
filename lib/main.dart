import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:ugrak_mekan_app/views/complete_profile_screen.dart';
import 'package:ugrak_mekan_app/widgets/auth_wrapper.dart';
import 'package:ugrak_mekan_app/services/onesignal_notification_service.dart';
import 'views/home_screen.dart';
import 'package:ugrak_mekan_app/views/main_screen.dart';
import "package:ugrak_mekan_app/views/user_profile_screen.dart";
import 'package:ugrak_mekan_app/views/chat_detail_screen.dart';
import 'package:ugrak_mekan_app/views/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutter motorunun hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  // .env dosyasını yüklüyoruz (Tüm API anahtarları burada olmalı)
  await dotenv.load(fileName: ".env");

  // Supabase başlatma
  await Supabase.initialize(
    url: dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  // OneSignal başlatma
  final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
  if (oneSignalAppId != null && oneSignalAppId.isNotEmpty && oneSignalAppId != 'YOUR_ONESIGNAL_APP_ID_HERE') {
    debugPrint('🔔 OneSignal başlatılıyor...');
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);
    
    // Bildirim izni iste
    await OneSignal.Notifications.requestPermission(true);
    
    // Navigator key'i OneSignal servisine ata
    OneSignalNotificationService.navigatorKey = navigatorKey;
    
    debugPrint('✅ OneSignal başlatıldı');
  } else {
    debugPrint('⚠️ OneSignal App ID bulunamadı. .env dosyasını kontrol edin.');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Renk Paleti Sabitleri
    const Color deepGreen = Color(0xFF346739);
    const Color midGreen = Color(0xFF79AE6F);
    const Color vanilla = Color(0xFFFAF8F3);

    return MaterialApp(
      navigatorKey: navigatorKey, // Deep linking için navigator key
      debugShowCheckedModeBanner: false,
      title: 'Uğrak',
      theme: ThemeData(
        useMaterial3: true,
        // Eski Turuncu gitti, Doğa Yeşili geldi
        colorSchemeSeed: const Color.fromARGB(255, 20, 40, 20),

        // Sayfa arka planlarını hafif kırık beyaz yaparak daha modern bir hava katıyoruz
        scaffoldBackgroundColor: const Color(0xFFFCFDF6),

        // Yazı tipi ayarlarını global olarak Urbanist yapıyoruz
        textTheme: GoogleFonts.urbanistTextTheme(Theme.of(context).textTheme)
            .copyWith(
              displayLarge: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: const Color.fromRGBO(20, 40, 20, 1),
              ),
              titleLarge: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color.fromRGBO(20, 40, 20, 1),
              ),
              bodyMedium: GoogleFonts.inter(
                color: const Color.fromRGBO(20, 40, 20, 1).withOpacity(0.8),
              ),
            ),

        // Uygulama genelindeki buton tasarımları
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(20, 40, 20, 1),
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),

        // Filtreleme çiplerinin tasarımı
        chipTheme: ChipThemeData(
          backgroundColor: vanilla.withOpacity(0.4),
          selectedColor: midGreen,
          labelStyle: GoogleFonts.plusJakartaSans(
            color: const Color.fromRGBO(20, 40, 20, 1),
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide.none,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/home': (context) => const HomeScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
        '/user-profile': (context) => const UserProfileScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
      onGenerateRoute: (settings) {
        // Chat detail için dinamik route
        if (settings.name == '/chat_detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatId: args['chatId'] as String,
                otherUser: args['otherUser'] as Map<String, dynamic>,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
