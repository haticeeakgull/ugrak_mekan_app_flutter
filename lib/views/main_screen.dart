import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'user_profile_screen.dart';
import 'explore_screen.dart'; // YENİ: Keşfet ekranını import ettik

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Alt menüde görünecek sayfalar
  final List<Widget> _pages = [
    const HomeScreen(), // 0: Uğrak (AI Arama)
    const ExploreScreen(), // 1: Keşfet (Harita + Kullanıcı Arama) - "Harita Yakında" yerine bu geldi
    const UserProfileScreen(), // 2: Profilim (targetUserId boş olduğu için otomatik SİZİN profiliniz açılır)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sayfayı gösteren alan - IndexedStack kullanmak sayfalar arası geçişte verilerin kaybolmamasını sağlar
      body: IndexedStack(index: _currentIndex, children: _pages),

      // Alt Menü Çubuğu
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType
            .fixed, // 3'ten fazla item olursa kaymaması için
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Uğrak',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profilim',
          ),
        ],
      ),
    );
  }
}
