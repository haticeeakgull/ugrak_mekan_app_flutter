import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import '../services/leaderboard_service.dart';
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _leaderboardService = LeaderboardService();
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, int> _myPointBreakdown = {};
  int _myRank = 0;
  bool _isLoading = true;

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color vanilla = const Color(0xFFF2EDC2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final results = await Future.wait([
        _leaderboardService.getLeaderboard(limit: 100),
        _leaderboardService.getUserRank(myId),
        _leaderboardService.getUserPointBreakdown(myId),
      ]);

      if (mounted) {
        setState(() {
          _leaderboard = results[0] as List<Map<String, dynamic>>;
          _myRank = results[1] as int;
          _myPointBreakdown = results[2] as Map<String, int>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: vanilla,
      appBar: AppBar(
        title: const Text(
          'Liderlik Tablosu',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: deepGreen,
          labelColor: deepGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Sıralama'),
            Tab(text: 'Puanlarım'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(),
          _buildMyPointsTab(),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: deepGreen),
      );
    }

    return RefreshIndicator(
      color: deepGreen,
      onRefresh: _loadData,
      child: Column(
        children: [
          // Kullanıcının kendi sırası
          _buildMyRankCard(),

          // Top 3 özel kartlar
          if (_leaderboard.length >= 3) _buildTopThree(),

          // Geri kalan liste
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _leaderboard.length - 3,
              itemBuilder: (context, index) {
                final actualIndex = index + 3;
                return _buildLeaderboardItem(
                  _leaderboard[actualIndex],
                  actualIndex + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankCard() {
    final myId = _supabase.auth.currentUser?.id;
    final myData = _leaderboard.firstWhere(
      (user) => user['id'] == myId,
      orElse: () => {},
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [deepGreen, midGreen],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: deepGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#$_myRank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Senin Sıran',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${myData['total_points'] ?? 0} puan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.emoji_events,
            color: Colors.white.withOpacity(0.5),
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. sıra
          Expanded(child: _buildPodiumCard(_leaderboard[1], 2, 160)),
          const SizedBox(width: 8),
          // 1. sıra
          Expanded(child: _buildPodiumCard(_leaderboard[0], 1, 200)),
          const SizedBox(width: 8),
          // 3. sıra
          Expanded(child: _buildPodiumCard(_leaderboard[2], 3, 140)),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(Map<String, dynamic> user, int rank, double height) {
    final colors = {
      1: Colors.amber,
      2: Colors.grey[400]!,
      3: Colors.brown[300]!,
    };

    final medals = {
      1: '🥇',
      2: '🥈',
      3: '🥉',
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(targetUserId: user['id']),
        ),
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors[rank]!, width: 3),
          boxShadow: [
            BoxShadow(
              color: colors[rank]!.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              medals[rank]!,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 30,
              backgroundColor: deepGreen.withOpacity(0.1),
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Icon(Icons.person, color: deepGreen, size: 30)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              user['username'] ?? 'Kullanıcı',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${user['total_points']} puan',
              style: TextStyle(
                color: colors[rank],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: deepGreen.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: deepGreen,
                ),
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: deepGreen.withOpacity(0.1),
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Icon(Icons.person, color: deepGreen, size: 24)
                  : null,
            ),
          ],
        ),
        title: Text(
          user['username'] ?? 'Kullanıcı',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: user['full_name'] != null
            ? Text(
                user['full_name'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${user['total_points']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: deepGreen,
              ),
            ),
            Text(
              'puan',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(targetUserId: user['id']),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPointsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: deepGreen),
      );
    }

    final breakdown = _myPointBreakdown;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toplam puan kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [deepGreen, midGreen],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Toplam Puanın',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${breakdown['total_points']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#$_myRank sıradasın',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Puan Dağılımı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Puan detayları
          _buildPointCard(
            '📸 Paylaşımlar',
            breakdown['post_points']!,
            '15 puan/paylaşım',
            Icons.photo_camera,
          ),
          _buildPointCard(
            '💬 Yorumlar',
            breakdown['comment_points']!,
            '10 puan/yorum',
            Icons.comment,
          ),
          _buildPointCard(
            '❤️ Beğeniler',
            breakdown['like_points']!,
            '5 puan/beğeni',
            Icons.favorite,
          ),
          _buildPointCard(
            '👥 Takipçiler',
            breakdown['follow_points']!,
            '5 puan/takipçi',
            Icons.people,
          ),
          _buildPointCard(
            '🏆 Rozetler',
            breakdown['badge_points']!,
            'Rozet puanları',
            Icons.emoji_events,
          ),
        ],
      ),
    );
  }

  Widget _buildPointCard(
    String title,
    int points,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: deepGreen.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: deepGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: deepGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: deepGreen,
            ),
          ),
        ],
      ),
    );
  }
}
