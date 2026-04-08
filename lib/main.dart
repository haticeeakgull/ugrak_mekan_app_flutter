import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/complete_profile_screen.dart';
import 'package:ugrak_mekan_app/widgets/auth_wrapper.dart';
import 'views/home_screen.dart';
import 'package:ugrak_mekan_app/views/main_screen.dart';
import "package:ugrak_mekan_app/views/user_profile_screen.dart";

void main() async {
  // Flutter motorunun hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yüklüyoruz (Tüm API anahtarları burada olmalı)
  await dotenv.load(fileName: ".env");

  // Supabase başlatma (EXPO_PUBLIC ön eklerini .env dosyanla eşleşecek şekilde korudum)
  await Supabase.initialize(
    url: dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Uğrak',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/home': (context) => const HomeScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
        '/user-profile': (context) => const UserProfileScreen(),
      },
    );
  }
}
