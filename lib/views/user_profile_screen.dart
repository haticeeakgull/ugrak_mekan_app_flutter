import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/follow_list_screen.dart';
import 'package:ugrak_mekan_app/views/post_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import '../services/collection_service.dart';
import '../services/follow_service.dart';
import '../widgets/share_sheet.dart';
import '../widgets/collection_card.dart';
import '../widgets/profile_widgets.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';
import 'complete_profile_screen.dart';
import 'create_post_screen.dart';
import 'collection_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const UserProfileScreen({super.key, this.targetUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  final CollectionService _collectionService = CollectionService();
  final FollowService _followService = FollowService();

  bool _isLoading = true;
  String _followStatus = "none";
  Map<String, dynamic>? _profileData;
  List<dynamic> _userPosts = [];
  List<dynamic> _userCollections = [];

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  // Future<List<Map<String, dynamic>>> fetchUserBadges(String userId) async {
  //   try {
  //     final supabase = Supabase.instance.client;

  //     // NOT: Eğer tabloların 'badge_id' ve 'cafe_id' üzerinden bağlıysa
  //     // bu yazım şekli Supabase'in en sağlıklı ilişki kurma yöntemidir.
  //     final response = await supabase
  //         .from('user_badges')
  //         .select('''
  //         *,
  //         badges:badge_id (*),
  //         cafes:cafe_id (name)
  //       ''')
  //         .eq('user_id', userId);

  //     debugPrint("Gelen Veri: $response"); // Konsolu mutlaka kontrol et!
  //     return List<Map<String, dynamic>>.from(response);
  //   } catch (e) {
  //     debugPrint("Hata: $e");
  //     return [];
  //   }
  // }

  Future<void> _loadAllProfileData() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final String myId = currentUser.id;
    final String userId = widget.targetUserId ?? myId;

    if (mounted && _userPosts.isEmpty) setState(() => _isLoading = true);

    try {
      if (userId != myId) {
        _followStatus = await _followService.getFollowStatus(myId, userId);
      }

      final List<dynamic> results = await Future.wait<dynamic>([
        _supabase.from('profiles').select().eq('id', userId).maybeSingle(),
        _supabase
            .from('cafe_postlar')
            .select(
              '*, ilce_isimli_kafeler(kafe_adi), profiles(username, avatar_url)',
            )
            .eq('user_id', userId)
            .order('paylasim_tarihi', ascending: false),
        _collectionService.fetchUserCollections(userId),
      ]);

      if (mounted) {
        setState(() {
          _profileData = results[0] as Map<String, dynamic>?;
          _userPosts = results[1] as List<dynamic>;
          _userCollections = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- YENİ: PROFİL FOTOĞRAFI GÖRÜNTÜLEME ---
  void _showFullProfileImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppScaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'profile_pic_zoom',
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person, color: Colors.white, size: 100),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostGrid() {
    if (_userPosts.isEmpty) {
      return const Center(child: Text("Henüz bir uğrak paylaşılmamış."));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  allPosts: _userPosts.cast<Map<String, dynamic>>(),
                  initialIndex: index,
                ),
              ),
            ).then((_) => _loadAllProfileData());
          },
          child: Hero(
            tag: 'post_${post['id']}',
            child: Image.network(
              post['foto_url'] ?? "https://via.placeholder.com/150",
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  void _onShareCollection(Map<String, dynamic> col) {
    showAdvancedShareSheet(
      context,
      col['id'].toString(),
      col['isim'] ?? "Koleksiyon",
    );
  }

  Widget _buildNotificationBadge() {
    final String myId = _supabase.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('notifications').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Icon(Icons.notifications_none);

        final allNotifications = snapshot.data ?? [];
        final unreadNotifications = allNotifications
            .where((n) => n['receiver_id'] == myId && n['is_read'] == false)
            .toList();

        bool hasUnread = unreadNotifications.isNotEmpty;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.black,
                size: 26,
              ),
              onPressed: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ).then((_) {
                    if (mounted) setState(() {});
                  }),
            ),
            if (hasUnread)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _handleFollowAction() async {
    final myId = _supabase.auth.currentUser!.id;
    final targetId = widget.targetUserId!;
    final bool isPrivate = _profileData?['is_private'] ?? false;

    try {
      if (_followStatus == "following" || _followStatus == "pending") {
        bool confirm = await _showExitConfirmDialog();
        if (!confirm) return;
        await _followService.unfollowUser(myId, targetId);
      } else {
        await _followService.followUser(
          myId: myId,
          targetId: targetId,
          isPrivate: isPrivate,
        );
      }
      _loadAllProfileData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
      }
    }
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
                  ? "Takip isteğini geri çekmek istiyor musunuz?"
                  : "Bu kullanıcıyı takipten çıkmak istediğinize emin misiniz?",
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text(
          "Hesabınızdan çıkış yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabase.auth.signOut();
            },
            child: const Text(
              "Evet, Çıkış Yap",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF346739)),
        ),
      );
    }

    final String currentUserId = _supabase.auth.currentUser!.id;
    final String userId = widget.targetUserId ?? currentUserId;
    final bool isMe = userId == currentUserId;
    final bool isPrivate = _profileData?['is_private'] ?? false;
    final bool canSeeContent =
        isMe || !isPrivate || _followStatus == "following";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: !isMe ? const BackButton(color: Colors.black) : null,
        title: Text(
          _profileData?['username'] ?? "Kullanıcı",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isMe) ...[
            IconButton(
              icon: const Icon(Icons.send_outlined, color: Colors.black),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              ),
            ),
            _buildNotificationBadge(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _showLogoutDialog,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF346739),
        onRefresh: _loadAllProfileData,
        child: DefaultTabController(
          length: 2,
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(userId),
                    _buildBioSection(),
                    _buildMainActions(isMe),
                    const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 8)),
                    if (isMe) buildBadgeSection(userId),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    indicatorColor: const Color(0xFF346739),
                    labelColor: const Color(0xFF346739),
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on), text: "Uğraklarım"),
                      Tab(
                        icon: Icon(Icons.bookmark_border),
                        text: "Koleksiyonlar",
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                canSeeContent
                    ? _buildPostGrid()
                    : _buildPrivateAccountMessage(),
                canSeeContent
                    ? _buildCollectionGrid(isMe)
                    : _buildPrivateAccountMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String userId) {
    final String avatarUrl =
        _profileData?['avatar_url'] ?? "https://via.placeholder.com/150";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // GÜNCELLEDİĞİMİZ KISIM: Profil Fotoğrafı Tıklanabilir ve Hero Efektli
          GestureDetector(
            onTap: () => _showFullProfileImage(avatarUrl),
            child: Hero(
              tag: 'profile_pic_zoom',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 2),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: NetworkImage(avatarUrl),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  _userPosts.length.toString(),
                  "Uğrak",
                  userId,
                  -1,
                ),
                _buildRealtimeStatItem("Takipçi", userId, 0),
                _buildRealtimeStatItem("Takip", userId, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeStatItem(String label, String userId, int index) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('follows').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildStatItem("0", label, userId, index);

        final allFollows = snapshot.data ?? [];
        final filteredFollows = allFollows.where((f) {
          final isCorrectUser = (label == "Takipçi")
              ? f['following_id'] == userId
              : f['follower_id'] == userId;
          return isCorrectUser && f['status'] == 'following';
        }).toList();

        return _buildStatItem(
          filteredFollows.length.toString(),
          label,
          userId,
          index,
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, String userId, int index) {
    return GestureDetector(
      onTap: () {
        if (label == "Takipçi" || label == "Takip") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowListScreen(
                userId: userId,
                username: _profileData?['username'] ?? "Profil",
                initialIndex: index,
              ),
            ),
          ).then((_) => _loadAllProfileData());
        }
      },
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _profileData?['full_name'] ?? "Ad Soyad",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            _profileData?['bio'] ?? "Henüz bir biyografi eklenmemiş.",
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(bool isMe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: isMe
                ? OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompleteProfileScreen(),
                      ),
                    ).then((_) => _loadAllProfileData()),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Profili Düzenle",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : _buildOtherProfileButton(),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.black),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                ).then((_) => _loadAllProfileData()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherProfileButton() {
    String buttonText = "Takip Et";
    Color btnColor = const Color(0xFF346739);
    Color textColor = Colors.white;

    if (_followStatus == "following") {
      buttonText = "Takipten Çık";
      btnColor = Colors.grey[200]!;
      textColor = Colors.black;
    } else if (_followStatus == "pending") {
      buttonText = "İstek Gönderildi";
      btnColor = Colors.grey[300]!;
      textColor = Colors.black;
    }

    return ElevatedButton(
      onPressed: _handleFollowAction,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        buttonText,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCollectionGrid(bool isMe) {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.95,
          ),
          itemCount: _userCollections.length,
          itemBuilder: (context, index) {
            final col = _userCollections[index];
            return CollectionCard(
              collection: col,
              isMe: isMe,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(
                    collectionId: col['id'].toString(),
                    collectionName: col['isim'] ?? "Koleksiyon",
                    ownerId: col['user_id']?.toString(),
                  ),
                ),
              ),
              onShare: () => _onShareCollection(col),
              onMenuSelected: (val) async {
                if (val == 'delete') {
                  await _collectionService.deleteCollection(col['id'].toString());
                  _loadAllProfileData();
                } else if (val == 'privacy') {
                  await _collectionService.updatePrivacy(
                    col['id'].toString(),
                    col['is_public'] ?? true,
                  );
                  _loadAllProfileData();
                }
              },
            );
          },
        ),
        // Floating "Yeni Koleksiyon" butonu (sadece kendi profilinde)
        if (isMe)
          Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF346739),
              child: InkWell(
                onTap: _onCreateCollection,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Yeni Koleksiyon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrivateAccountMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
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

  void _onCreateCollection() {
    final controller = TextEditingController();
    const deepGreen = Color(0xFF346739);
    const midGreen = Color(0xFF79AE6F);
    const vanilla = Color(0xFFF2EDC2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: vanilla,
        title: const Text(
          "Yeni Koleksiyon",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: deepGreen,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favori mekanlarını bir araya getir',
              style: TextStyle(
                color: midGreen,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: deepGreen,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Örn: Çalışma Mekanlarım",
                hintStyle: TextStyle(
                  color: deepGreen.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Vazgeç",
              style: TextStyle(
                color: midGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: deepGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _collectionService.createCollection(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  _loadAllProfileData();
                }
              }
            },
            child: const Text(
              "Oluştur",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
