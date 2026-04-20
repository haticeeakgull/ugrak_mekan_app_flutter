import 'package:flutter/material.dart';
import '../../views/post_detail_screen.dart';

class DiscoverySheetWidget extends StatelessWidget {
  final List<Map<String, dynamic>>? discoveryPosts;
  const DiscoverySheetWidget({super.key, this.discoveryPosts});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.14, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              Expanded(
                child: discoveryPosts == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      )
                    : discoveryPosts!.isEmpty
                    ? const Center(
                        child: Text("Henüz keşfedilecek post bulunamadı."),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: discoveryPosts!.length,
                        itemBuilder: (context, index) => _buildPostItem(
                          context,
                          discoveryPosts![index],
                          index,
                        ),
                      ),
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
    return Container(
      height: 480,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(post['foto_url'] ?? "", fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black12,
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepOrange,
                        child: Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post['baslik'] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => PostDetailScreen(
                          allPosts: discoveryPosts!,
                          initialIndex: index,
                        ),
                      ),
                    ),
                    child: const Text("Detayları İncele"),
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
