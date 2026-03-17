import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; // Paylaşım için gerekli
import 'create_post_screen.dart';
import 'collection_detail_screen.dart';

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

  // --- VERİ YÜKLEME ---
  Future<void> _loadAllProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final postsResponse = await _supabase
          .from('cafe_postlar')
          .select()
          .eq('user_id', user.id)
          .order('paylasim_tarihi', ascending: false);

      if (mounted) {
        setState(() {
          _profileData = profileResponse;
          _userPosts = postsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Profil Yükleme Hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- KOLEKSİYON İŞLEMLERİ ---

  // Paylaşım Yapma
  Future<void> _shareCollection(
    String collectionName,
    String collectionId,
  ) async {
    // Senin GitHub Pages üzerinden oluşturduğun gerçek yol
    final String shareLink =
        "https://haticeeakgull.github.io/koleksiyon/$collectionId";

    final String message =
        "Uğrak'taki '$collectionName' koleksiyonuma göz at! 🏙️\n"
        "Mekanları görmek için tıkla: $shareLink";

    await Share.share(message);
  }

  // Gizlilik Değiştirme
  Future<void> _togglePrivacy(String collectionId, bool currentStatus) async {
    try {
      await _supabase
          .from('koleksiyonlar')
          .update({'is_public': !currentStatus})
          .eq('id', collectionId);
      setState(() {}); // Arayüzü yenile
    } catch (e) {
      debugPrint("Gizlilik hatası: $e");
    }
  }

  // Koleksiyon Silme
  Future<void> _deleteCollection(String collectionId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Koleksiyonu Sil"),
        content: const Text(
          "Bu koleksiyonu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('koleksiyonlar').delete().eq('id', collectionId);
        setState(() {});
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Koleksiyon silindi.")));
      } catch (e) {
        debugPrint("Silme hatası: $e");
      }
    }
  }

  // Yeni Koleksiyon Oluşturma Dialogu
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
                decoration: const InputDecoration(
                  hintText: "Koleksiyon adı",
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepOrange),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                title: const Text(
                  "Herkese Açık",
                  style: TextStyle(fontSize: 14),
                ),
                value: isPublic,
                activeColor: Colors.deepOrange,
                onChanged: (val) => setDialogState(() => isPublic = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _supabase.from('koleksiyonlar').insert({
                    'isim': controller.text.trim(),
                    'user_id': _supabase.auth.currentUser!.id,
                    'is_public': isPublic,
                  });
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text(
                "Oluştur",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI WIDGETLARI ---

  Widget _buildCollectionGrid() {
    final user = _supabase.auth.currentUser;
    return FutureBuilder(
      future: _supabase
          .from('koleksiyonlar')
          .select()
          .eq('user_id', user?.id ?? '')
          .order('isim', ascending: true),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepOrange),
          );
        final collections = snapshot.data as List? ?? [];

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: collections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
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
                      SizedBox(height: 8),
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

            final collection = collections[index - 1];
            final bool isPublic = collection['is_public'] ?? true;
            final String collectionId = collection['id'].toString();

            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CollectionDetailScreen(
                    collectionId: collectionId,
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
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
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
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              collection['isim'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(
                          isPublic ? Icons.public : Icons.lock_outline,
                          size: 18,
                          color: isPublic ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _togglePrivacy(collectionId, isPublic),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteCollection(collectionId),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.ios_share,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () =>
                            _shareCollection(collection['isim'], collectionId),
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
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                const TabBar(
                  labelColor: Colors.deepOrange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepOrange,
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on), text: "Uğraklarım"),
                    Tab(
                      icon: Icon(Icons.bookmark_border),
                      text: "Koleksiyonlarım",
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [_buildPostGrid(_userPosts), _buildCollectionGrid()],
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
                    ? NetworkImage(_profileData!['avatar_url'])
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
            _profileData?['full_name'] ?? "Kullanıcı",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 5),
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
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 3,
            itemBuilder: (context, index) => Container(
              width: 60,
              margin: const EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
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
      itemBuilder: (context, index) => Image.network(
        posts[index]['foto_url'],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image),
        ),
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
}

// --- TAB BAR DELEGATE ---
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
