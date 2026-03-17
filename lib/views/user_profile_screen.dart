import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'create_post_screen.dart';
import 'collection_detail_screen.dart';
import 'notifications_screen.dart'; // Bu dosyayı oluşturmuş olman gerekiyor

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
  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  // --- VERİ YÜKLEME ---
  Future<void> _loadAllProfileData() async {
    final String userId = widget.targetUserId ?? _supabase.auth.currentUser!.id;
    final String myId = _supabase.auth.currentUser!.id;

    if (mounted) setState(() => _isLoading = true);

    try {
      // Profil Bilgileri
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // Gönderiler
      final postsResponse = await _supabase
          .from('cafe_postlar')
          .select()
          .eq('user_id', userId)
          .order('paylasim_tarihi', ascending: false);

      // Takipçi ve Takip Sayıları (Sadece onaylanmış olanlar)
      final followers = await _supabase
          .from('follows')
          .select()
          .eq('following_id', userId)
          .eq('status', 'following');

      final following = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', userId)
          .eq('status', 'following');

      // Takip Durumu Kontrolü (Eğer başkasının profiliyse)
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
          _profileData = profileResponse;
          _userPosts = postsResponse;
          _followerCount = followers.length;
          _followingCount = following.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Profil Yükleme Hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- TAKİP ETME / ÇIKMA / İSTEK GÖNDERME ---
  Future<void> _handleFollowButton() async {
    final myId = _supabase.auth.currentUser!.id;
    final targetId = widget.targetUserId!;
    final bool isPrivate = _profileData?['is_private'] ?? false;

    try {
      if (_followStatus == "following" || _followStatus == "pending") {
        // Takipten çıkma veya bekleyen isteği iptal etme onayı
        bool confirm = await _showExitConfirmDialog();
        if (!confirm) return;

        await _supabase.from('follows').delete().match({
          'follower_id': myId,
          'following_id': targetId,
        });

        // Varsa bildirimi de silebilirsin (isteğe bağlı)
      } else {
        // Yeni Takip / İstek
        String newStatus = isPrivate ? "pending" : "following";

        await _supabase.from('follows').insert({
          'follower_id': myId,
          'following_id': targetId,
          'status': newStatus,
        });

        // Bildirim tablosuna ekle
        await _supabase.from('notifications').insert({
          'sender_id': myId,
          'receiver_id': targetId,
          'type': isPrivate ? 'follow_request' : 'follow_accept',
        });
      }
      _loadAllProfileData();
    } catch (e) {
      debugPrint("Takip işlemi hatası: $e");
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    String title = _followStatus == "pending"
        ? "İsteği Geri Çek"
        : "Takipten Çık";
    String content = _followStatus == "pending"
        ? "Takip isteğini geri çekmek istediğine emin misin?"
        : "Bu kullanıcıyı takipten çıkmak istediğine emin misin?";

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Vazgeç"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(title, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- KOLEKSİYON İŞLEMLERİ ---
  Future<void> _shareCollection(
    String collectionName,
    String collectionId,
  ) async {
    final String shareLink =
        "https://haticeeakgull.github.io/koleksiyon/$collectionId";
    final String message =
        "Uğrak'taki '$collectionName' koleksiyonuma göz at! 🏙️\n$shareLink";
    await Share.share(message);
  }

  Future<void> _togglePrivacy(String collectionId, bool currentStatus) async {
    try {
      await _supabase
          .from('koleksiyonlar')
          .update({'is_public': !currentStatus})
          .eq('id', collectionId);
      _loadAllProfileData();
    } catch (e) {
      debugPrint("Gizlilik hatası: $e");
    }
  }

  Future<void> _deleteCollection(String collectionId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Koleksiyonu Sil"),
        content: const Text("Bu koleksiyonu silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.from('koleksiyonlar').delete().eq('id', collectionId);
      _loadAllProfileData();
    }
  }

  Future<void> _showCreateCollectionDialog() async {
    final TextEditingController controller = TextEditingController();
    bool isPublic = true;

    return showDialog(
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
                activeColor: Colors.deepOrange,
                onChanged: (val) => setDialogState(() => isPublic = val),
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
                if (controller.text.isNotEmpty) {
                  await _supabase.from('koleksiyonlar').insert({
                    'isim': controller.text.trim(),
                    'user_id': _supabase.auth.currentUser!.id,
                    'is_public': isPublic,
                  });
                  if (mounted) Navigator.pop(context);
                  _loadAllProfileData();
                }
              },
              child: const Text("Oluştur"),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI WIDGETLARI ---
  Widget _buildPrivateAccountMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
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

  Future<void> _showLogoutDialog() async {
    return showDialog(
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
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Çıkış', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGrid(List<dynamic> posts) {
    if (posts.isEmpty)
      return const Center(child: Text("Henüz bir paylaşım yok."));
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) =>
          Image.network(posts[index]['foto_url'], fit: BoxFit.cover),
    );
  }

  Widget _buildCollectionGrid() {
    final String userId = widget.targetUserId ?? _supabase.auth.currentUser!.id;
    final bool isMe =
        widget.targetUserId == null ||
        widget.targetUserId == _supabase.auth.currentUser!.id;

    return FutureBuilder(
      future: isMe
          ? _supabase
                .from('koleksiyonlar')
                .select()
                .eq('user_id', userId)
                .order('isim', ascending: true)
          : _supabase
                .from('koleksiyonlar')
                .select()
                .eq('user_id', userId)
                .eq('is_public', true)
                .order('isim', ascending: true),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final collections = snapshot.data as List? ?? [];

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: isMe ? collections.length + 1 : collections.length,
          itemBuilder: (context, index) {
            if (isMe && index == 0) {
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
                        color: Colors.orange,
                      ),
                      Text(
                        "Yeni Oluştur",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final collection = collections[isMe ? index - 1 : index];
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
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
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
                          Text(
                            collection['isim'],
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
                            collection['is_public']
                                ? Icons.public
                                : Icons.lock_outline,
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );

    final bool isMe =
        widget.targetUserId == null ||
        widget.targetUserId == _supabase.auth.currentUser!.id;
    final bool isPrivate = _profileData?['is_private'] ?? false;
    final bool showContent = isMe || !isPrivate || _followStatus == "following";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _profileData?['username'] ?? "Profil",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isMe) ...[
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: Colors.black,
                size: 28,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
                _loadAllProfileData();
              },
              icon: const Icon(
                Icons.add_box_outlined,
                color: Colors.deepOrange,
                size: 28,
              ),
            ),
            IconButton(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
            ),
          ],
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(),
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
              showContent
                  ? _buildPostGrid(_userPosts)
                  : _buildPrivateAccountMessage(),
              showContent
                  ? _buildCollectionGrid()
                  : _buildPrivateAccountMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final bool isMe =
        widget.targetUserId == null ||
        widget.targetUserId == _supabase.auth.currentUser!.id;

    // Buton Tasarımı Ayarları
    String btnText = "Takip Et";
    Color btnColor = Colors.deepOrange;
    Color textColor = Colors.white;

    if (_followStatus == "following") {
      btnText = "Takipten Çık";
      btnColor = Colors.grey[200]!;
      textColor = Colors.black;
    } else if (_followStatus == "pending") {
      btnText = "İstek Gönderildi";
      btnColor = Colors.grey[300]!;
      textColor = Colors.black54;
    }

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
            _profileData?['full_name'] ?? "Kullanıcı",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            _profileData?['bio'] ?? "Henüz bir bio eklenmemiş.",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: isMe
                ? OutlinedButton(
                    onPressed: () {},
                    child: const Text(
                      "Profili Düzenle",
                      style: TextStyle(color: Colors.black),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      elevation: 0,
                    ),
                    onPressed: _handleFollowButton,
                    child: Text(btnText, style: TextStyle(color: textColor)),
                  ),
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
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 3,
            itemBuilder: (context, index) => Container(
              width: 60,
              margin: const EdgeInsets.only(right: 15),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.orange,
                size: 30,
              ),
            ),
          ),
        ),
      ],
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
