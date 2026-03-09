import 'package:flutter/material.dart';
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

  // Sayfayı aşağı çekince çalışacak yenileme fonksiyonu
  Future<void> _handleRefresh() async {
    setState(() {}); // FutureBuilder'ı tetikler
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Yorumları veritabanından taze çekme
  Future<List<Map<String, dynamic>>> _fetchComments() async {
    final response = await supabase
        .from('cafe_yorumlar')
        .select('*, yorum_begenileri(count)')
        .eq('cafe_id', widget.cafe.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Yorum Silme
  Future<void> _deleteComment(dynamic commentId) async {
    try {
      await supabase.from('cafe_yorumlar').delete().eq('id', commentId);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yorum başarıyla silindi.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Beğenme/Geri Alma
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
      print("Beğeni hatası: $e");
    }
  }

  // Yorum Gönderme
  Future<void> _sendComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Lütfen önce giriş yapın.";

      final profileData = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();

      final String gercekKullaniciAdi = profileData['username'] ?? 'Anonim';

      await supabase.from('cafe_yorumlar').insert({
        'cafe_id': widget.cafe.id,
        'kullanici_id': user.id,
        'kullanici_adi': gercekKullaniciAdi,
        'yorum_metni': commentText,
      });

      setState(() {
        _commentController.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yorum paylaşıldı!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
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
                      children: [
                        _buildCommentList(),
                        _buildPostList(widget.cafe.postlar),
                      ],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final comments = snapshot.data ?? [];
        if (comments.isEmpty) {
          // Liste boşken bile refresh çalışması için ListView dönüyoruz
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Center(child: Text("Henüz yorum yapılmamış.")),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          // RefreshIndicator ile uyumlu çalışması için AlwaysScrollableScrollPhysics şart
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final yorum = comments[index];
            final currentUserId = supabase.auth.currentUser?.id;
            final bool isMyComment = yorum['kullanici_id'] == currentUserId;

            final int likeCount = (yorum['yorum_begenileri'] as List).isNotEmpty
                ? yorum['yorum_begenileri'][0]['count'] ?? 0
                : 0;

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
                      // Yorum kartı içindeki Row kısmını şu şekilde güncelle:
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
                          const SizedBox(width: 8), // Biraz boşluk
                          Text(
                            // 'created_at' Supabase'den String gelir, onu DateTime'a çevirip timeago'ya veriyoruz
                            timeago.format(
                              DateTime.parse(yorum['created_at']),
                              locale: 'tr',
                            ),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
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
                          onPressed: () => _showDeleteDialog(yorum['id']),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    yorum['yorum_metni'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
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
                        Text(
                          "$likeCount Beğeni",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
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

  void _showDeleteDialog(dynamic commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yorumu Sil"),
        content: const Text(
          "Bu yorumu kalıcı olarak silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () {
              _deleteComment(commentId);
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    return SizedBox(
      height: 140,
      child: widget.cafe.fotograflar.isEmpty
          ? Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                  size: 40,
                ),
              ),
            )
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

  Widget _buildHeaderHandle() {
    return Center(
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
                hintText: "Bu mekan hakkında ne düşünüyorsun?",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _isSending
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FloatingActionButton.small(
                  onPressed: _sendComment,
                  backgroundColor: Colors.deepOrange,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
        ],
      ),
    );
  }

  Widget _buildPostList(List posts) =>
      const Center(child: Text("Henüz bir öneri paylaşılmamış."));
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
