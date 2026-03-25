import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allPosts;
  final int initialIndex;

  const PostDetailScreen({
    super.key,
    required this.allPosts,
    required this.initialIndex,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PageController _verticalController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _verticalController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        itemCount: widget.allPosts.length,
        itemBuilder: (context, index) {
          final post = widget.allPosts[index];
          return _HorizontalPostContainer(
            key: ValueKey(post['id']),
            post: post,
            supabase: supabase,
            onDelete: () => setState(() {
              widget.allPosts.removeAt(index);
            }),
          );
        },
      ),
    );
  }
}

class _HorizontalPostContainer extends StatefulWidget {
  final Map<String, dynamic> post;
  final SupabaseClient supabase;
  final VoidCallback onDelete;

  const _HorizontalPostContainer({
    super.key,
    required this.post,
    required this.supabase,
    required this.onDelete,
  });

  @override
  State<_HorizontalPostContainer> createState() =>
      _HorizontalPostContainerState();
}

class _HorizontalPostContainerState extends State<_HorizontalPostContainer> {
  late PageController _horizontalController;
  int _currentPage = 0;

  bool isLiked = false;
  int likeCount = 0;
  bool isSyncing = false;
  bool isLoadingLikes = true;

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    _loadLikeData();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  // Beğeni verilerini çekme işlemi (Mevcut mantığın korundu)
  Future<void> _loadLikeData() async {
    final userId = widget.supabase.auth.currentUser?.id;
    final postId = widget.post['id'];

    try {
      final response = await widget.supabase
          .from('post_likes')
          .select('*')
          .eq('post_id', postId);

      final int count = (response as List).length;

      bool userLiked = false;
      if (userId != null) {
        final likeRes = await widget.supabase
            .from('post_likes')
            .select()
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();
        userLiked = likeRes != null;
      }

      if (mounted) {
        setState(() {
          likeCount = count;
          isLiked = userLiked;
          isLoadingLikes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingLikes = false);
    }
  }

  Future<void> _handleLike() async {
    if (isSyncing) return;
    final userId = widget.supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isSyncing = true);
    final bool originalIsLiked = isLiked;
    final int originalLikeCount = likeCount;

    setState(() {
      isLiked = !isLiked;
      likeCount = isLiked ? likeCount + 1 : likeCount - 1;
    });

    try {
      if (originalIsLiked) {
        await widget.supabase.from('post_likes').delete().match({
          'post_id': widget.post['id'],
          'user_id': userId,
        });
      } else {
        await widget.supabase.from('post_likes').upsert({
          'post_id': widget.post['id'],
          'user_id': userId,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLiked = originalIsLiked;
          likeCount = originalLikeCount;
        });
      }
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> ratings = widget.post['degerlendirme'] ?? {};
    final List<dynamic> vibeler = ratings['secilen_vibeler'] ?? [];
    final String kullaniciAdi =
        widget.post['profiles']?['username'] ?? 'Anonim';

    // Çoklu fotoğraf desteği için liste kontrolü
    // Veritabanında 'foto_urls' adında bir List<String> olduğunu varsayıyorum.
    // Yoksa mevcut tekil 'foto_url'i listeye çeviriyoruz.
    final List<dynamic> imageList =
        widget.post['foto_listesi'] ??
        (widget.post['foto_url'] != null ? [widget.post['foto_url']] : []);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 45, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              PageView.builder(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                // Sayfa sayısı: Fotoğraf sayısı + 1 (Detay sayfası)
                itemCount: imageList.length + 1,
                itemBuilder: (context, index) {
                  if (index < imageList.length) {
                    // Fotoğraflar Sayfası
                    return _buildImagePage(
                      context,
                      imageList[index],
                      index == 0,
                    );
                  } else {
                    // En sondaki Detay Sayfası
                    return _buildDetailsPage(
                      context,
                      ratings,
                      vibeler,
                      kullaniciAdi,
                    );
                  }
                },
              ),

              // Üstteki Fotoğraf İndikatörleri (Instagram stili)
              if (imageList.length > 1)
                Positioned(
                  top: 15,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: List.generate(
                      imageList.length + 1,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fotoğraf Sayfası Tasarımı
  Widget _buildImagePage(
    BuildContext context,
    String imageUrl,
    bool isFirstPage,
  ) {
    return GestureDetector(
      onDoubleTap: _handleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          if (isFirstPage) // Başlık sadece ilk fotoğrafta görünsün
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post['baslik'] ?? 'Başlıksız',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.swipe_left, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Kaydırarak gez",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Mekan Karnesi ve Detaylar Sayfası
  Widget _buildDetailsPage(
    BuildContext context,
    Map<String, dynamic> ratings,
    List<dynamic> vibeler,
    String kullaniciAdi,
  ) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade50,
                  child: Text(
                    kullaniciAdi.isNotEmpty
                        ? kullaniciAdi[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  kullaniciAdi,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.post['icerik'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Mekan Karnesi",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildRatingCard(ratings),
            if (vibeler.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: vibeler
                    .map(
                      (v) => Chip(
                        label: Text("#$v"),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Alt Bar ve Rating Widgetları (Mevcut kodların aynısı) ---
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          InkWell(
            onTap: _handleLike,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 28,
                    color: isLiked ? Colors.red : Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  isLoadingLikes
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        )
                      : Text(
                          "$likeCount",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (widget.post['kullanici_id'] ==
              widget.supabase.auth.currentUser?.id)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _showDeleteDialog(context, widget.post['id']),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> ratings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildRatingItem(
            Icons.wifi,
            "İnternet",
            (ratings['internet'] ?? 0).toDouble(),
            Colors.blue,
          ),
          _buildRatingItem(
            Icons.power,
            "Priz",
            (ratings['priz'] ?? 0).toDouble(),
            Colors.green,
          ),
          _buildRatingItem(
            Icons.volume_up,
            "Ses",
            (ratings['ses'] ?? 0).toDouble(),
            Colors.orange,
          ),
          _buildRatingItem(
            Icons.work_outline,
            "Çalışma",
            (ratings['calisma'] ?? 0).toDouble(),
            Colors.purple,
          ),
          _buildRatingItem(
            Icons.people_outline,
            "Doluluk",
            (ratings['Kalabalık'] ?? 0).toDouble(),
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingItem(
    IconData icon,
    String label,
    double rating,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                "${rating.toInt()}/5",
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: rating / 5,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 3,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Postu Sil"),
        content: const Text("Bu öneriyi kaldırmak istediğine emin misin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () async {
              await widget.supabase
                  .from('cafe_postlar')
                  .delete()
                  .eq('id', postId);
              if (mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                widget.onDelete();
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
