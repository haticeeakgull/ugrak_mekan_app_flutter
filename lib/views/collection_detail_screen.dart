import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Kendi dosya yoluna göre bu importu kontrol et:
import "package:ugrak_mekan_app/widgets/cafe_detail_sheet.dart";
import 'package:ugrak_mekan_app/models/cafe_model.dart';

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

  // Sadece kafeleri çeken temizlenmiş sorgu
  Future<List<Map<String, dynamic>>> _fetchCollectionItems() async {
    try {
      final response = await supabase
          .from('koleksiyon_ogeleri')
          .select('''
            id,
            cafe_id,
            ilce_isimli_kafeler (
              id,
              kafe_adi
            )
          ''')
          .eq('koleksiyon_id', widget.collectionId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
      return [];
    }
  }

  Future<void> _removeFromCollection(dynamic itemId) async {
    try {
      await supabase.from('koleksiyon_ogeleri').delete().eq('id', itemId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mekan koleksiyondan kaldırıldı.')),
        );
      }
    } catch (e) {
      debugPrint("Kaldırma hatası: $e");
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
              final cafe = item['ilce_isimli_kafeler'];

              // Eğer veri tabanında bir hata varsa boş dönmesin
              if (cafe == null) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: Colors.deepOrange,
                    ),
                  ),
                  title: Text(
                    cafe['kafe_adi'] ?? 'İsimsiz Mekan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Kayıtlı Mekan",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeFromCollection(item['id']),
                  ),
                  onTap: () {
                    final hamKafeVerisi = item['ilce_isimli_kafeler'];
                    if (hamKafeVerisi != null) {
                      final kafeObjesi = Cafe.fromJson(hamKafeVerisi);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CafeDetailSheet(cafe: kafeObjesi),
                        ),
                      );
                    }
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
