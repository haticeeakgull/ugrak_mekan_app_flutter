import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchCollectionItems() async {
    // Koleksiyon öğelerini çekiyoruz ve içindeki post/kafe bilgilerini joinliyoruz
    final response = await supabase
        .from('koleksiyon_ogeleri')
        .select('''
          id,
          cafe_postlar (
            id,
            baslik,
            foto_url,
            paylasim_tarihi
          )
        ''')
        .eq('koleksiyon_id', widget.collectionId);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _removeFromCollection(dynamic itemId) async {
    try {
      await supabase.from('koleksiyon_ogeleri').delete().eq('id', itemId);
      setState(() {}); // Listeyi yenile
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koleksiyondan kaldırıldı.')),
        );
      }
    } catch (e) {
      print("Kaldırma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.collectionName,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCollectionItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text("Bu koleksiyon henüz boş ✨"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final post = item['cafe_postlar'];

              if (post == null) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      post['foto_url'] ?? 'https://via.placeholder.com/150',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    post['baslik'] ?? 'Başlıksız Post',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    timeago.format(
                      DateTime.parse(post['paylasim_tarihi']),
                      locale: 'tr',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeFromCollection(item['id']),
                  ),
                  onTap: () {
                    // Buraya tıklandığında PostDetailScreen'e yönlendirme yapabilirsin
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
