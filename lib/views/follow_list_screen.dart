import 'package:flutter/material.dart';
import '../services/follow_service.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final String username;
  final int initialIndex; // 0: Takipçiler, 1: Takip Edilenler

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialIndex,
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            username,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Takipçiler"),
              Tab(text: "Takip Edilenler"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowList(userId: userId, isFollowers: true),
            _FollowList(userId: userId, isFollowers: false),
          ],
        ),
      ),
    );
  }
}

class _FollowList extends StatefulWidget {
  final String userId;
  final bool isFollowers;

  const _FollowList({required this.userId, required this.isFollowers});

  @override
  State<_FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<_FollowList> {
  final FollowService _followService = FollowService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = widget.isFollowers
          ? await _followService.getFollowers(widget.userId)
          : await _followService.getFollowing(widget.userId);

      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Takip listesi yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Profil yönlendirme fonksiyonu (Tekrarı önlemek için)
  void _navigateToProfile(String targetId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(targetUserId: targetId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          widget.isFollowers
              ? "Henüz takipçi yok."
              : "Henüz kimse takip edilmiyor.",
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        // Supabase join yapısından gelen profil verisi
        final profile = _users[index]['profiles'] as Map<String, dynamic>;
        final String targetId = profile['id'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: () => _navigateToProfile(targetId), // Satıra tıklandığında git
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(
              profile['avatar_url'] ?? "https://via.placeholder.com/150",
            ),
          ),
          title: Text(
            profile['username'] ?? "Kullanıcı",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            profile['full_name'] ?? "",
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          trailing: SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: () =>
                  _navigateToProfile(targetId), // Butona basıldığında git
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                "Gör",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
