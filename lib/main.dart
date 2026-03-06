import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/complete_profile_screen.dart';
import 'package:ugrak_mekan_app/widgets/auth_wrapper.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env yükle
  await dotenv.load(fileName: ".env");

  // Supabase başlat
  await Supabase.initialize(
    url: dotenv.env['EXPO_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Uğrak Mekan',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      // Uygulama ilk açıldığında login kontrolü yapan wrapper
      home: const AuthWrapper(),

      // Sayfalar arası yönlendirme tanımları (Routes)
      routes: {
        '/home': (context) => const HomeScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
      },
    );
  }
}
