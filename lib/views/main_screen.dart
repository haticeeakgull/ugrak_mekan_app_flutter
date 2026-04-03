import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/explore_screen.dart';
import 'package:ugrak_mekan_app/views/home_screen.dart';
import 'package:ugrak_mekan_app/views/user_profile_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import '../widgets/badge_alert.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final SupabaseClient supabase = Supabase.instance.client;

  final Set<String> _shownBadgeIds = {}; // gösterilmiş rozetler

  final List<Widget> _pages = [
    const HomeScreen(),
    const ExploreScreen(),
    const UserProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenToBadges();
  }

  void _listenToBadges() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase
        .channel('badge-listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_badges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // .new hata veriyorsa newRecord kullanmalısın
            final Map<String, dynamic> newRecord = payload.newRecord;
            final badgeId = newRecord['badge_id'];
            final cafeId = payload.newRecord['cafe_id'];
            final String uniqueKey = "${badgeId}_$cafeId";

            if (badgeId == null) return;

            if (_shownBadgeIds.contains(uniqueKey)) return;

            try {
              final badgeData = await supabase
                  .from('badges')
                  .select()
                  .eq('id', badgeId)
                  .single();

              if (!mounted) return;

              _shownBadgeIds.add(uniqueKey);

              // Context'in hazır olduğundan emin olmak için
              WidgetsBinding.instance.addPostFrameCallback((_) {
                BadgeAlert.show(
                  context,
                  badgeData['title'],
                  badgeData['icon_url'],
                );
              });
            } catch (e) {
              debugPrint("Badge fetch error: $e");
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
