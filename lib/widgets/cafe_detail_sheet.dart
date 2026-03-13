import 'package:flutter/material.dart';
import 'package:ugrak_mekan_app/views/create_post_screen.dart';
import 'package:ugrak_mekan_app/views/post_detail_screen.dart';
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

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // --- Veritabanı İşlemleri ---

  Future<void> _deletePost(dynamic postId) async {
    try {
      await supabase.from('cafe_postlar').delete().eq('id', postId);
      setState(() {});
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

  Future<void> _deleteComment(dynamic commentId) async {
    try {
      await supabase.from('cafe_yorumlar').delete().eq('id', commentId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCafePosts() async {
    final response = await supabase
        .from('cafe_postlar')
        .select('*, profiles:user_id (username)')
        .eq('cafe_id', widget.cafe.id)
        .order('paylasim_tarihi', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchComments() async {
    try {
      final response = await supabase
          .from('cafe_yorumlar')
          .select('*, profiles!cafe_yorumlar_kullanici_id_fkey (username)')
          .eq('cafe_id', widget.cafe.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> _sendComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Giriş yapın.";

      await supabase.from('cafe_yorumlar').insert({
        'cafe_id': widget.cafe.id,
        'kullanici_id': user.id,
        'yorum_metni': commentText,
      });

      _commentController.clear();
      FocusScope.of(context).unfocus();
      setState(() {});
    } catch (e) {
      print("Hata: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --- Koleksiyon İşlemi ---

  void _showCollectionPicker(String postId) {
    final TextEditingController newCollectionController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text(
                    "Koleksiyona Kaydet",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newCollectionController,
                    decoration: InputDecoration(
                      hintText: "Yeni koleksiyon oluştur...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.deepOrange,
                        ),
                        onPressed: () async {
                          if (newCollectionController.text.isNotEmpty) {
                            await supabase.from('koleksiyonlar').insert({
                              'isim': newCollectionController.text.trim(),
                              'user_id': supabase.auth.currentUser!.id,
                            });
                            newCollectionController.clear();
                            setModalState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: FutureBuilder(
                      future: supabase
                          .from('koleksiyonlar')
                          .select()
                          .eq('user_id', supabase.auth.currentUser!.id),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final collections = snapshot.data as List? ?? [];
                        if (collections.isEmpty)
                          return const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("Henüz bir koleksiyonun yok."),
                          );

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: collections.length,
                          itemBuilder: (context, index) {
                            final coll = collections[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.folder_open,
                                color: Colors.orange,
                              ),
                              title: Text(coll['isim']),
                              trailing: const Icon(Icons.add, size: 20),
                              onTap: () async {
                                try {
                                  await supabase
                                      .from('koleksiyon_ogeleri')
                                      .insert({
                                        'koleksiyon_id': coll['id'],
                                        'post_id': postId,
                                        'user_id':
                                            supabase.auth.currentUser!.id,
                                      });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Koleksiyona eklendi! ✨"),
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Bu zaten eklenmiş!"),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
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

  // --- Widget Yapısı ---

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                _buildHeaderHandle(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => setState(() {}),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.cafe.kafeAdi,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // İŞTE İSTEDİĞİN BUTON BURADA:
                                      IconButton(
                                        icon: const Icon(
                                          Icons.bookmark_border,
                                          color: Colors.deepOrange,
                                          size: 28,
                                        ),
                                        onPressed: () => _showCollectionPicker(
                                          widget.cafe.id.toString(),
                                        ),
                                      ),
                                    ],
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
          ),
        );
      },
    );
  }

  Widget _buildPostList() {
    return CustomScrollView(
      key: const PageStorageKey('oneriler'),
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Önerini Paylaş",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: const Icon(Icons.add_a_photo, color: Colors.deepOrange),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(cafeId: widget.cafe.id),
              ),
            ).then((_) => setState(() {})),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchCafePosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            final posts = snapshot.data ?? [];
            if (posts.isEmpty)
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Henüz öneri yok."),
                  ),
                ),
              );
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildPostCard(posts[index], posts, index);
                }, childCount: posts.length),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchComments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final comments = snapshot.data ?? [];
        if (comments.isEmpty)
          return const Center(child: Text("Henüz yorum yok."));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (context, index) => _buildCommentCard(comments[index]),
        );
      },
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> yorum) {
    final String yazarAdi = yorum['profiles']?['username'] ?? 'Anonim';
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
              Text(
                yazarAdi,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (yorum['kullanici_id'] == supabase.auth.currentUser?.id)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: () => _deleteComment(yorum['id']),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(yorum['yorum_metni'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> post,
    List<Map<String, dynamic>> allPosts,
    int index,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PostDetailScreen(allPosts: allPosts, initialIndex: index),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (post['foto_url'] != null)
                  Image.network(
                    post['foto_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      if (post['user_id'] == supabase.auth.currentUser?.id)
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _deletePost(post['id']),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      post['baslik'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _isSending
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FloatingActionButton.small(
                  onPressed: _sendComment,
                  backgroundColor: Colors.deepOrange,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCafePosts(),
      builder: (context, snapshot) {
        List<String> allImages = List.from(widget.cafe.fotograflar);
        if (snapshot.hasData) {
          final postImages = snapshot.data!
              .where((post) => post['foto_url'] != null)
              .map((post) => post['foto_url'] as String)
              .toList();
          allImages.addAll(postImages);
        }
        if (allImages.isEmpty)
          return const SizedBox(
            height: 140,
            child: Center(
              child: Text(
                "Henüz fotoğraf yok",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );

        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, index) {
              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(allImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        );
      },
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
