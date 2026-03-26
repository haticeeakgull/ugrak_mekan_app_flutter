import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/create_post_screen.dart';

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
            onDelete: () {
              setState(() {
                widget.allPosts.removeAt(index);
              });
            },
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
        });
      }
    } catch (e) {
      debugPrint("Like data error: $e");
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
                itemCount: imageList.length + 1,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  if (index < imageList.length) {
                    return _buildImagePage(imageList[index], index == 0);
                  } else {
                    return _buildDetailsPage();
                  }
                },
              ),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageList.length + 1,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.deepOrange
                            : Colors.grey.withOpacity(0.5),
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

  Widget _buildImagePage(String url, bool isFirst) {
    // Kafe adı için güvenli çekim
    final String cafeName =
        widget.post['ilce_isimli_kafeler']?['kafe_adi'] ??
        widget.post['kafe_adi'] ??
        'Bilinmeyen Mekan';

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(url, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
        if (isFirst)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post['baslik'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cafeName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsPage() {
    final Map<String, dynamic> ratings = widget.post['degerlendirme'] ?? {};
    // Vibe etiketlerini hem degerlendirme içinde hem de ana seviyede ara
    final List<dynamic> vibes =
        ratings['secilen_vibeler'] ?? widget.post['secilen_vibeler'] ?? [];
    final String user = widget.post['profiles']?['username'] ?? 'Anonim';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepOrange.shade100,
                child: Text(
                  user.isNotEmpty ? user[0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                user,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Deneyimim",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.post['icerik'] ?? 'Yorum belirtilmemiş.',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),

          const Divider(height: 40),

          const Text(
            "Mekan Karnesi",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 20),

          // Tüm özelliklerin listesi
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
            "Ses Seviyesi",
            (ratings['ses'] ?? 0).toDouble(),
            Colors.orange,
          ),
          _buildRatingItem(
            Icons.groups,
            "Kalabalık",
            (ratings['kalabalik'] ?? 0).toDouble(),
            Colors.purple,
          ),
          _buildRatingItem(
            Icons.laptop,
            "Çalışma Uygunluğu",
            (ratings['calisma'] ?? 0).toDouble(),
            Colors.teal,
          ),
          _buildRatingItem(
            Icons.music_note,
            "Müzik",
            (ratings['muzik'] ?? 0).toDouble(),
            Colors.pink,
          ),

          const SizedBox(height: 30),
          if (vibes.isNotEmpty) ...[
            const Text(
              "Vibe Etiketleri",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vibes
                  .map(
                    (v) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.deepOrange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        v.toString(),
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 100),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                "${rating.toInt()}/5",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rating / 5,
              minHeight: 8,
              color: color,
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final currentUserId = widget.supabase.auth.currentUser?.id;
    final bool isMyPost = currentUserId == widget.post['user_id'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleLike,
            child: Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black87,
                ),
                const SizedBox(width: 6),
                Text(
                  "$likeCount",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (isMyPost) ...[
            IconButton(
              icon: const Icon(
                Icons.edit_note_rounded,
                color: Colors.blue,
                size: 28,
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreatePostScreen(initialPostData: widget.post),
                  ),
                );
                if (result != null &&
                    result is Map<String, dynamic> &&
                    mounted) {
                  setState(() {
                    widget.post.addAll(result);
                  });
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 26,
              ),
              onPressed: () => _showDeleteDialog(context, widget.post['id']),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Postu Sil"),
        content: const Text("Bu harika anıyı silmek istediğine emin misin?"),
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
                widget.onDelete();
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Sil",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
