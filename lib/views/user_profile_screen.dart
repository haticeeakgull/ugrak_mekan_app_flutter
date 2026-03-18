import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/chat_list_screen.dart';
import 'create_post_screen.dart';
import 'collection_detail_screen.dart';
import 'notifications_screen.dart';
import 'complete_profile_screen.dart'; // Profil düzenleme sayfası için

class UserProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const UserProfileScreen({super.key, this.targetUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _followStatus = "none"; // "none", "pending", "following"

  Map<String, dynamic>? _profileData;
  List<dynamic> _userPosts = [];
  List<dynamic> _userCollections = [];
  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  Future<void> _loadAllProfileData() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final String myId = currentUser.id;
    final String userId = widget.targetUserId ?? myId;

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _supabase.from('profiles').select().eq('id', userId).maybeSingle(),
        _supabase
            .from('cafe_postlar')
            .select()
            .eq('user_id', userId)
            .order('paylasim_tarihi', ascending: false),
        _supabase
            .from('follows')
            .select()
            .eq('following_id', userId)
            .eq('status', 'following'),
        _supabase
            .from('follows')
            .select()
            .eq('follower_id', userId)
            .eq('status', 'following'),
        (widget.targetUserId == null || widget.targetUserId == myId)
            ? _supabase
                  .from('koleksiyonlar')
                  .select()
                  .eq('user_id', userId)
                  .order('isim')
            : _supabase
                  .from('koleksiyonlar')
                  .select()
                  .eq('user_id', userId)
                  .eq('is_public', true)
                  .order('isim'),
      ]);

      if (userId != myId) {
        final followCheck = await _supabase
            .from('follows')
            .select('status')
            .eq('follower_id', myId)
            .eq('following_id', userId)
            .maybeSingle();
        _followStatus = followCheck != null ? followCheck['status'] : "none";
      }

      if (mounted) {
        setState(() {
          _profileData = results[0] as Map<String, dynamic>?;
          _userPosts = results[1] as List<dynamic>;
          _followerCount = (results[2] as List).length;
          _followingCount = (results[3] as List).length;
          _userCollections = results[4] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowButton() async {
    final myId = _supabase.auth.currentUser!.id;
    final targetId = widget.targetUserId!;
    final bool isPrivate = _profileData?['is_private'] ?? false;

    try {
      if (_followStatus == "following" || _followStatus == "pending") {
        bool confirm = await _showExitConfirmDialog();
        if (!confirm) return;
        await _supabase.from('follows').delete().match({
          'follower_id': myId,
          'following_id': targetId,
        });
      } else {
        String newStatus = isPrivate ? "pending" : "following";
        await _supabase.from('follows').insert({
          'follower_id': myId,
          'following_id': targetId,
          'status': newStatus,
        });
        await _supabase.from('notifications').insert({
          'sender_id': myId,
          'receiver_id': targetId,
          'type': isPrivate ? 'follow_request' : 'follow_accept',
        });
      }
      _loadAllProfileData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
    }
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

    final bool isMe =
        widget.targetUserId == null ||
        widget.targetUserId == _supabase.auth.currentUser?.id;
    final bool isPrivate = _profileData?['is_private'] ?? false;
    final bool canSeeContent =
        isMe || !isPrivate || _followStatus == "following";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(isMe),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(isMe),
                  _buildBadgeSection(),
                  const SizedBox(height: 10),
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
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.grid_on),
                      text: isMe ? "Uğraklarım" : "Uğraklar",
                    ),
                    Tab(
                      icon: const Icon(Icons.bookmark_border),
                      text: "Koleksiyonlar",
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              canSeeContent ? _buildPostGrid() : _buildPrivateAccountMessage(),
              canSeeContent
                  ? _buildCollectionGrid(isMe)
                  : _buildPrivateAccountMessage(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isMe) {
    return AppBar(
      title: Text(
        _profileData?['username'] ?? "Profil",
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        if (isMe) ...[
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatListScreen()),
            ),
            icon: const Icon(
              Icons.near_me_outlined,
              color: Colors.black,
              size: 26,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, size: 28),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              _loadAllProfileData();
            },
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(
              Icons.logout,
              color: Color.fromARGB(255, 10, 10, 10),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileHeader(bool isMe) {
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
                    ? NetworkImage(_profileData!['avatar_url'])
                    : null,
                child: _profileData?['avatar_url'] == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(_userPosts.length.toString(), "Uğrak"),
                    _buildStatColumn(_followerCount.toString(), "Takipçi"),
                    _buildStatColumn(_followingCount.toString(), "Takip"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _profileData?['full_name'] ?? "Uğrak Kullanıcısı",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _profileData?['bio'] ?? "Henüz bir açıklama eklenmedi.",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 15),

          // DÜZELTİLEN BUTON ALANI
          isMe
              ? Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompleteProfileScreen(),
                          ),
                        ),
                        child: const Text(
                          "Profili Düzenle",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(
                            color: Color.fromARGB(255, 10, 10, 10),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreatePostScreen(),
                            ),
                          );
                          _loadAllProfileData();
                        },
                        child: const Icon(Icons.add, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _followStatus == "none"
                          ? const Color.fromARGB(255, 4, 4, 4)
                          : Colors.grey[200],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _handleFollowButton,
                    child: Text(
                      _followStatus == "none"
                          ? "Takip Et"
                          : (_followStatus == "pending"
                                ? "İstek Gönderildi"
                                : "Takipten Çık"),
                      style: TextStyle(
                        color: _followStatus == "none"
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // --- Diğer Yardımcı Widgetlar (Stat, Badge, Grid vb.) ---

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
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              // Farklı renklerde madalyalar
              final colors = [Colors.orange, Colors.blueGrey, Colors.amber];
              return Container(
                width: 60,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: colors[index].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: colors[index],
                  size: 30,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostGrid() {
    if (_userPosts.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Henüz bir paylaşım yok."),
        ),
      );
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) =>
          Image.network(_userPosts[index]['foto_url'], fit: BoxFit.cover),
    );
  }

  Widget _buildCollectionGrid(bool isMe) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: isMe ? _userCollections.length + 1 : _userCollections.length,
      itemBuilder: (context, index) {
        if (isMe && index == 0) return _buildCreateCollectionCard();
        final collection = _userCollections[isMe ? index - 1 : index];
        return _buildCollectionCard(collection, isMe);
      },
    );
  }

  Widget _buildCollectionCard(dynamic collection, bool isMe) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionDetailScreen(
            collectionId: collection['id'].toString(),
            collectionName: collection['isim'],
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_special,
                    size: 45,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collection['isim'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (isMe)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(
                    collection['is_public'] ? Icons.public : Icons.lock_outline,
                    size: 18,
                  ),
                  onPressed: () => _togglePrivacy(
                    collection['id'].toString(),
                    collection['is_public'],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCollectionCard() {
    return InkWell(
      onTap: _showCreateCollectionDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 40,
              color: Color.fromARGB(255, 7, 7, 7),
            ),
            Text(
              "Yeni Oluştur",
              style: TextStyle(
                color: Color.fromARGB(255, 1, 1, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Yardımcı Fonksiyonlar ---

  Future<void> _togglePrivacy(String collectionId, bool currentStatus) async {
    await _supabase
        .from('koleksiyonlar')
        .update({'is_public': !currentStatus})
        .eq('id', collectionId);
    _loadAllProfileData();
  }

  Future<void> _showCreateCollectionDialog() async {
    final controller = TextEditingController();
    bool isPublic = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni Koleksiyon"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Koleksiyon adı"),
              ),
              SwitchListTile(
                title: const Text("Herkese Açık"),
                value: isPublic,
                onChanged: (v) => setDialogState(() => isPublic = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('koleksiyonlar').insert({
                  'isim': controller.text,
                  'user_id': _supabase.auth.currentUser!.id,
                  'is_public': isPublic,
                });
                Navigator.pop(context);
                _loadAllProfileData();
              },
              child: const Text("Oluştur"),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _followStatus == "pending" ? "İsteği Geri Çek" : "Takipten Çık",
            ),
            content: Text(
              _followStatus == "pending"
                  ? "İsteği geri çekmek istiyor musunuz?"
                  : "Takipten çıkmak istiyor musunuz?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Vazgeç"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Onayla",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showLogoutDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await _supabase.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Çıkış', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateAccountMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const Text(
            "Bu Hesap Gizli",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text(
            "İçerikleri görmek için takip etmelisin.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

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
  ) => Container(color: Colors.white, child: _tabBar);
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
