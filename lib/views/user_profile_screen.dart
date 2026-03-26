import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/follow_list_screen.dart';
import 'package:ugrak_mekan_app/views/post_detail_screen.dart'; // Yeni eklendi
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
            // DETAY SAYFASI İÇİN İLİŞKİSEL VERİLERİ (KAFE ADI VB.) ÇEKİYORUZ
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

  // --- UĞRAKLARIM (GRID) YAPISI ---
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
            // KEŞFETTEKİ GİBİ KAYDIRILABİLİR DETAY SAYFASINA GİDİŞ
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  allPosts: _userPosts
                      .cast<Map<String, dynamic>>(), // Tüm postlar listesi
                  initialIndex: index, // Tıklanan postun sırası
                ),
              ),
            ).then(
              (_) => _loadAllProfileData(),
            ); // Silme/güncelleme ihtimaline karşı yenile
          },
          child: Hero(
            tag: 'post_${post['id']}', // Yumuşak geçiş animasyonu
            child: Image.network(
              post['foto_url'] ?? "https://via.placeholder.com/150",
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  // --- KOLEKSİYON PAYLAŞMA MANTIĞI ---
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
          child: CircularProgressIndicator(color: Colors.deepOrange),
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
        color: Colors.deepOrange,
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
                    if (isMe) buildBadgeSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    indicatorColor: Colors.deepOrange,
                    labelColor: Colors.deepOrange,
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
                    ? _buildPostGrid() // Güncellenen metod
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

  // --- STAT VE HEADER YARDIMCILARI (AYNEN KORUNDU) ---
  Widget _buildProfileHeader(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(
              _profileData?['avatar_url'] ?? "https://via.placeholder.com/150",
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
    Color btnColor = Colors.deepOrange;
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
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _userCollections.length + (isMe ? 1 : 0),
      itemBuilder: (context, index) {
        if (isMe && index == 0) {
          return InkWell(
            onTap: _onCreateCollection,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange[100]!),
              ),
              child: const Icon(Icons.add, size: 40, color: Colors.deepOrange),
            ),
          );
        }
        final col = _userCollections[isMe ? index - 1 : index];
        return CollectionCard(
          collection: col,
          isMe: isMe,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollectionDetailScreen(
                collectionId: col['id'].toString(),
                collectionName: col['isim'] ?? "Koleksiyon",
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Koleksiyon"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Koleksiyon adı"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _collectionService.createCollection(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  _loadAllProfileData();
                }
              }
            },
            child: const Text("Oluştur"),
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
