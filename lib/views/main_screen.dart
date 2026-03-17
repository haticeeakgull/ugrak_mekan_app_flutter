import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'user_profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Alt menüde görünecek sayfalar
  final List<Widget> _pages = [
    const HomeScreen(), // Arama/Akış sayfan
    const Center(
      child: Text("Harita Yakında"),
    ), 
    const UserProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sayfayı gösteren alan
      body: _pages[_currentIndex],

      // Alt Menü Çubuğu
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Uğrak'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Keşfet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profilim'),
        ],
      ),
    );
  }
}
