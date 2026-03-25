import 'package:flutter/material.dart';

class CollectionCard extends StatelessWidget {
  final dynamic collection;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final Function(String action) onMenuSelected;

  const CollectionCard({
    super.key,
    required this.collection,
    required this.isMe,
    required this.onTap,
    required this.onShare,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
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
                  Text(
                    collection['isim'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (isMe)
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: onMenuSelected,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'privacy',
                      child: Text(
                        collection['is_public'] ? "Gizle" : "Herkese Aç",
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text("Sil", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 5,
              right: 5,
              child: IconButton(
                icon: const Icon(
                  Icons.ios_share,
                  size: 18,
                  color: Colors.blueAccent,
                ),
                onPressed: onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
