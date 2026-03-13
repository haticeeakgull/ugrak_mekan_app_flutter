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
            key: ValueKey(post['id']), // Her post için benzersiz key
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

  bool isLiked = false;
  int likeCount = 0;
  bool isSyncing = false;
  bool isLoadingLikes = true; // İlk açılışta sayının yüklenmesi için

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    // İlk açılışta hem beğeni sayısını hem de kullanıcının beğenip beğenmediğini çekiyoruz
    _loadLikeData();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  // --- YENİ: VERİTABANINDAN CANLI SAYI VE DURUM ÇEKME ---
  Future<void> _loadLikeData() async {
    final userId = widget.supabase.auth.currentUser?.id;
    final postId = widget.post['id'];

    try {
      // 1. Toplam beğeni sayısını say (DÜZELTİLMİŞ KISIM)
      // count: CountOption.exact parametresini select içine alıyoruz
      final response = await widget.supabase
          .from('post_likes')
          .select('*')
          .eq('post_id', postId)
          .count(
            CountOption.exact,
          ); // Count artık select dışında veya farklı bir yapıda olabilir

      // 2. Kullanıcı beğenmiş mi kontrol et
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
          // response.count doğrudan toplam sayıyı verir
          likeCount = response.count;
          isLiked = userLiked;
          isLoadingLikes = false;
        });
      }
    } catch (e) {
      debugPrint("Beğeni verisi yüklenirken hata: $e");
      if (mounted) setState(() => isLoadingLikes = false);
    }
  }

  // --- GÜNCELLENMİŞ BEĞENİ FONKSİYONU (SÜTUNSUZ) ---
  Future<void> _handleLike() async {
    if (isSyncing) return;

    final userId = widget.supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isSyncing = true);

    // Optimistik Güncelleme (Hız hissi için)
    final bool originalIsLiked = isLiked;
    final int originalLikeCount = likeCount;

    setState(() {
      isLiked = !isLiked;
      likeCount = isLiked ? likeCount + 1 : likeCount - 1;
    });

    try {
      if (originalIsLiked) {
        // Beğeniyi kaldır
        await widget.supabase
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', userId);
      } else {
        // Beğeni ekle
        await widget.supabase.from('post_likes').upsert({
          'post_id': widget.post['id'],
          'user_id': userId,
        }, onConflict: 'user_id, post_id');
      }
      // NOT: Burada 'cafe_postlar' tablosuna update atmıyoruz, sütun yok çünkü!
    } catch (e) {
      // Hata olursa eski haline döndür
      if (mounted) {
        setState(() {
          isLiked = originalIsLiked;
          likeCount = originalLikeCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bağlantı hatası.")));
      }
      debugPrint("Beğeni işlemi hatası: $e");
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 45, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              PageView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                children: [
                  _buildMainPage(context, kullaniciAdi),
                  _buildDetailsPage(context, ratings, vibeler, kullaniciAdi),
                ],
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

  // --- SAYFA TASARIMLARI (DEĞİŞMEDİ) ---

  Widget _buildMainPage(BuildContext context, String kullaniciAdi) {
    return GestureDetector(
      onDoubleTap: _handleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.post['foto_url'] != null)
            Image.network(widget.post['foto_url'], fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
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
                    Icon(Icons.swipe_left, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text("Detaylar", style: TextStyle(color: Colors.white70)),
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

  Widget _buildDetailsPage(
    BuildContext context,
    Map<String, dynamic> ratings,
    List<dynamic> vibeler,
    String kullaniciAdi,
  ) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade50,
                  child: Text(
                    kullaniciAdi[0].toUpperCase(),
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
            const SizedBox(height: 25),
            Text(
              widget.post['icerik'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 35),
            const Divider(),
            const SizedBox(height: 20),
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
          const SizedBox(width: 8),

          // BEĞENİ BUTONU (YÜKLENME DURUMLU)
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
          const Icon(Icons.bookmark_border, size: 28),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGETLAR ---

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
