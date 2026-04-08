import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/collection_service.dart'; // Dosya yolun doğru olmalı

void showAdvancedShareSheet(
  BuildContext context,
  String colId,
  String colName,
) {
  final collectionService = CollectionService();
  final supabase = Supabase.instance.client;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "Arkadaşlarına Gönder",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: supabase.from('profiles').select().limit(10),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final friend = snapshot.data![index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          friend['avatar_url'] ?? "",
                        ),
                      ),
                      title: Text(friend['username'] ?? "Kullanıcı"),
                      trailing: TextButton(
                        onPressed: () async {
                          await collectionService.sendToFriend(
                            friend['id'],
                            colId,
                            colName,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Gönderildi!")),
                          );
                        },
                        child: const Text("Gönder"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Diğer Uygulamalarla Paylaş"),
            onTap: () {
              Share.share(
                '$colName koleksiyonuma göz at!\nhttps://haticeeakgull.github.io/?koleksiyonId=$colId',
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}
