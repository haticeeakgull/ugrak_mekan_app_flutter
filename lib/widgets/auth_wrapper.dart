import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "package:ugrak_mekan_app/views/auth_screen.dart";
import "package:ugrak_mekan_app/views/home_screen.dart";

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase'in anlık oturum durumunu dinliyoruz
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Eğer veri henüz gelmediyse yükleme ikonu göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        // Oturum (session) varsa Ana Sayfaya, yoksa Giriş Ekranına git
        if (session != null) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
