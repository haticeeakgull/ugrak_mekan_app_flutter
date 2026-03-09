import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic>? _profileData;
  List<dynamic> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  // --- VERİ ÇEKME FONKSİYONU ---
  Future<void> _loadAllProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Profil Verisini Çek
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      debugPrint("DEBUG: Gelen Profil Verisi -> $profileResponse");

      // 2. Postları Çek (Hata ihtimaline karşı try-catch içinde)
      List<dynamic> postsResponse = [];
      try {
        postsResponse = await _supabase
            .from('posts')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
      } catch (postError) {
        debugPrint("DEBUG: Post çekme hatası: $postError");
      }

      if (mounted) {
        setState(() {
          _profileData = profileResponse;
          _userPosts = postsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Genel Profil Hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ÇIKIŞ ONAY DİYALOĞU ---
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Çıkış Yap'),
          content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Çıkış Yap'),
              onPressed: () async {
                Navigator.of(context).pop(); // Diyaloğu kapat
                await _supabase.auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _profileData?['username'] ?? "Uğrak Noktam",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/complete_profile'),
            icon: const Icon(Icons.edit_note, color: Colors.black, size: 28),
          ),
          IconButton(
            onPressed: _showLogoutDialog, // Diyaloğu çağırır
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    _buildBadgeSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    labelColor: Colors.deepOrange,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepOrange,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on), text: "Uğraklarım"),
                      Tab(
                        icon: Icon(Icons.bookmark_border),
                        text: "Kaydedilenler",
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [_buildPostGrid(_userPosts), _buildPostGrid([])],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.grey[200],
                backgroundImage: _profileData?['avatar_url'] != null
                    ? NetworkImage(
                        _profileData!['avatar_url'].toString().startsWith(
                              'http',
                            )
                            ? _profileData!['avatar_url']
                            : _supabase.storage
                                  .from('AVATARS')
                                  .getPublicUrl(_profileData!['avatar_url']),
                      )
                    : null,
                child: _profileData?['avatar_url'] == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(_userPosts.length.toString(), "Uğrak"),
                    _buildStatColumn("0", "Takipçi"),
                    _buildStatColumn("0", "Takip"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _profileData?['full_name'] ?? "İsimsiz Kullanıcı",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _profileData?['bio'] ?? "Henüz bir bio eklenmemiş.",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Uğrak Başarıları",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.orange,
                  size: 35,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostGrid(List<dynamic> posts) {
    if (posts.isEmpty) {
      return const Center(child: Text("Henüz bir paylaşım yok."));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return Image.network(posts[index]['image_url'], fit: BoxFit.cover);
      },
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// --- SLIVER DELEGATE ---
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
