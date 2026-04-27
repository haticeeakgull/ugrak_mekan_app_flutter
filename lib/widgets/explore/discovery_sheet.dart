import 'package:flutter/material.dart';
import '../../views/post_detail_screen.dart';

class DiscoverySheetWidget extends StatefulWidget {
  final List<Map<String, dynamic>>? discoveryPosts;
  final VoidCallback? onLoadMore;
  final bool isLoading;
  
  const DiscoverySheetWidget({
    super.key,
    this.discoveryPosts,
    this.onLoadMore,
    this.isLoading = false,
  });

  @override
  State<DiscoverySheetWidget> createState() => _DiscoverySheetWidgetState();
}

class _DiscoverySheetWidgetState extends State<DiscoverySheetWidget> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.14, 0.95],
      builder: (context, scrollController) {
        // Scroll listener for pagination
        scrollController.addListener(() {
          if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent - 200 &&
              !widget.isLoading &&
              widget.onLoadMore != null) {
            widget.onLoadMore!();
          }
        });

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: widget.discoveryPosts == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF346739),
                  ),
                )
              : widget.discoveryPosts!.isEmpty
              ? CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 15),
                          Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "Sana Özel Keşifler",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 100),
                          const Text("Henüz keşfedilecek post bulunamadı."),
                        ],
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // Header (tutamaç ve başlık) - scrollable içinde
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 15),
                          Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "Sana Özel Keşifler",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Post listesi
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == widget.discoveryPosts!.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF346739),
                                ),
                              ),
                            );
                          }
                          return _buildPostItem(
                            context,
                            widget.discoveryPosts![index],
                            index,
                          );
                        },
                        childCount: widget.discoveryPosts!.length + (widget.isLoading ? 1 : 0),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 120),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPostItem(
    BuildContext context,
    Map<String, dynamic> post,
    int index,
  ) {
    final String username = post['profiles'] != null
        ? post['profiles']['username'] ?? 'Anonim'
        : 'Anonim';
    final String kafeAdi = post['kafe_adi'] ?? 'Bilinmeyen Mekan';
    final double? distance =
        post['distance']; // Controller'da hesapladığımız mesafe

    return Container(
      height: 480,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Görsel
            Image.network(
              post['foto_url'] ?? "",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
            // Karartma Gradient (Yazıların okunması için)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black26,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
            // İçerik
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kullanıcı Bilgisi
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF346739),
                        child: Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Başlık
                  Text(
                    post['baslik'] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Kafe Adı ve Mesafe
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "$kafeAdi ${distance != null ? '• ${(distance / 1000).toStringAsFixed(1)} km' : ''}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Buton
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Colors.white30),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => PostDetailScreen(
                            allPosts: widget.discoveryPosts!,
                            initialIndex: index,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Detayları İncele",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
