import 'package:flutter/material.dart';
import 'package:ugrak_mekan_app/views/create_post_screen.dart';
import '../models/cafe_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class CafeDetailSheet extends StatefulWidget {
  final Cafe cafe;
  const CafeDetailSheet({super.key, required this.cafe});

  @override
  State<CafeDetailSheet> createState() => _CafeDetailSheetState();
}

class _CafeDetailSheetState extends State<CafeDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('tr', timeago.TrMessages());
  }

  // Öneri Postunu Silme Fonksiyonu
  Future<void> _deletePost(dynamic postId) async {
    try {
      await supabase.from('cafe_postlar').delete().eq('id', postId);
      setState(() {}); // Listeyi yeniler
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öneri başarıyla silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Öneri Silme Onay Diyaloğu
  void _showPostDeleteDialog(dynamic postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Öneriyi Sil"),
        content: const Text(
          "bu paylaşımı kaldırmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Öneri Post Kartı Tasarımı (GÜNCELLENDİ)
  Widget _buildPostCard(Map<String, dynamic> post) {
    final currentUserId = supabase.auth.currentUser?.id;
    final bool isMyPost = post['user_id'] == currentUserId; // Postun sahibi mi?

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                post['foto_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              // Eğer post benimse silme butonunu göster
              if (isMyPost)
                PositionAt(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showPostDeleteDialog(post['id']),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['baslik'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post['icerik'] ?? '',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DİĞER FONKSİYONLAR (DEĞİŞMEDİ) ---

  Future<List<Map<String, dynamic>>> _fetchCafePosts() async {
    final response = await supabase
        .from('cafe_postlar')
        .select()
        .eq('cafe_id', widget.cafe.id)
        .order('paylasim_tarihi', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _handleRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<List<Map<String, dynamic>>> _fetchComments() async {
    final response = await supabase
        .from('cafe_yorumlar')
        .select('*, yorum_begenileri(count)')
        .eq('cafe_id', widget.cafe.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _deleteComment(dynamic commentId) async {
    try {
      await supabase.from('cafe_yorumlar').delete().eq('id', commentId);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
    } catch (e) {
      print(e);
    }
  }

  Future<void> _toggleLike(dynamic commentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final existingLike = await supabase
          .from('yorum_begenileri')
          .select()
          .eq('yorum_id', commentId)
          .eq('kullanici_id', user.id)
          .maybeSingle();
      if (existingLike == null) {
        await supabase.from('yorum_begenileri').insert({
          'yorum_id': commentId,
          'kullanici_id': user.id,
        });
      } else {
        await supabase
            .from('yorum_begenileri')
            .delete()
            .eq('yorum_id', commentId)
            .eq('kullanici_id', user.id);
      }
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Giriş yapın.";
      final profileData = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      await supabase.from('cafe_yorumlar').insert({
        'cafe_id': widget.cafe.id,
        'kullanici_id': user.id,
        'kullanici_adi': profileData['username'] ?? 'Anonim',
        'yorum_metni': commentText,
      });
      _commentController.clear();
      setState(() {});
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              _buildHeaderHandle(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: Colors.deepOrange,
                  child: NestedScrollView(
                    controller: scrollController,
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.cafe.kafeAdi,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: widget.cafe.vibeEtiketleri
                                      .map(
                                        (v) => Chip(
                                          label: Text("#$v"),
                                          backgroundColor:
                                              Colors.orange.shade50,
                                          side: BorderSide.none,
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "Fotoğraflar",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildPhotoGallery(),
                              ],
                            ),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverAppBarDelegate(
                            TabBar(
                              controller: _tabController,
                              labelColor: Colors.deepOrange,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.deepOrange,
                              tabs: const [
                                Tab(text: "Yorumlar"),
                                Tab(text: "Öneriler"),
                              ],
                            ),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [_buildCommentList(), _buildPostList()],
                    ),
                  ),
                ),
              ),
              _buildCommentInputArea(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchComments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final comments = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final yorum = comments[index];
            final bool isMyComment =
                yorum['kullanici_id'] == supabase.auth.currentUser?.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.orange.shade50,
                            child: const Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            yorum['kullanici_adi'] ?? 'Anonim',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (isMyComment)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _deleteComment(yorum['id']),
                        ),
                    ],
                  ),
                  const Divider(),
                  Text(yorum['yorum_metni'] ?? ''),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _toggleLike(yorum['id']),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 5),
                        Text("Beğen"),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePostScreen(cafeId: widget.cafe.id),
              ),
            ).then((_) => setState(() {})),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.deepOrange),
                  SizedBox(width: 12),
                  Text("Önerini Paylaş"),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchCafePosts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final cafePosts = snapshot.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cafePosts.length,
                itemBuilder: (context, index) =>
                    _buildPostCard(cafePosts[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGallery() {
    return SizedBox(
      height: 140,
      child: widget.cafe.fotograflar.isEmpty
          ? const Center(child: Icon(Icons.image_not_supported_outlined))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.cafe.fotograflar.length,
              itemBuilder: (context, index) => Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(widget.cafe.fotograflar[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderHandle() => Center(
    child: Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  Widget _buildCommentInputArea() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 15,
        left: 15,
        right: 15,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "Düşüncen nedir?",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _isSending
              ? const CircularProgressIndicator()
              : FloatingActionButton.small(
                  onPressed: _sendComment,
                  backgroundColor: Colors.deepOrange,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
        ],
      ),
    );
  }
}

// Positioned için ufak bir yardımcı (Kodda Positioned kullanılabilir ama Stack içinde doğru çalışması için helper)
class PositionAt extends StatelessWidget {
  final double? top, right;
  final Widget child;
  const PositionAt({super.key, this.top, this.right, required this.child});
  @override
  Widget build(BuildContext context) =>
      Positioned(top: top, right: right, child: child);
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
