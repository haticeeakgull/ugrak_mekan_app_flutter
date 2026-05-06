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
  final Color lightCream = const Color(0xFFFAF8F3); // Daha açık krem-beyaz

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
      backgroundColor: lightCream,
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Kullanıcının kendi sırası
          _buildMyRankCard(),

          // Top 3 podium
          if (_leaderboard.length >= 3) _buildTopThreePodium(),

          const SizedBox(height: 16),

          // Geri kalan liste (4'ten başlayarak)
          ...List.generate(
            _leaderboard.length - 3,
            (index) {
              final actualIndex = index + 3;
              return _buildLeaderboardItem(
                _leaderboard[actualIndex],
                actualIndex + 1,
              );
            },
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

  Widget _buildTopThreePodium() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. sıra
          _buildPodiumUser(_leaderboard[1], 2),
          // 1. sıra (ortada ve daha büyük)
          _buildPodiumUser(_leaderboard[0], 1),
          // 3. sıra
          _buildPodiumUser(_leaderboard[2], 3),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(Map<String, dynamic> user, int rank) {
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 80.0 : 70.0;
    final borderColor = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
            ? const Color(0xFFC0C0C0) // Silver
            : const Color(0xFFCD7F32); // Bronze

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(targetUserId: user['id']),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Taç (sadece 1. sıra için)
          if (isFirst)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '👑',
                style: TextStyle(fontSize: 28),
              ),
            ),
          // Profil fotoğrafı (yuvarlak)
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? Icon(
                          Icons.person,
                          size: avatarSize / 2,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
              ),
              // Sıralama numarası (yuvarlağın altında)
              Positioned(
                bottom: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // İsim
          SizedBox(
            width: 100,
            child: Text(
              user['username'] ?? 'Kullanıcı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isFirst ? 15 : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Puan
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                size: 14,
                color: borderColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${user['total_points']} pts',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int rank) {
    final myId = _supabase.auth.currentUser?.id;
    final isMe = user['id'] == myId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? midGreen.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: deepGreen, width: 2)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isMe ? deepGreen : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: deepGreen.withOpacity(0.1),
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Icon(Icons.person, color: deepGreen, size: 22)
                  : null,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['username'] ?? 'Kullanıcı',
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isMe)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: deepGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          '${user['total_points']} pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isMe ? deepGreen : Colors.grey[700],
          ),
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
