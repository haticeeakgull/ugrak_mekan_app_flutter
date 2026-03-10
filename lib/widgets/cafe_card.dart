import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cafe_model.dart';
import '../views/map_screen.dart';

class CafeCard extends StatelessWidget {
  final Cafe cafe;
  final VoidCallback? onDelete; // Silme işleminden sonra listeyi yenilemek için

  const CafeCard({super.key, required this.cafe, this.onDelete});

  // Silme işlemini gerçekleştiren fonksiyon
  Future<void> _postuSil(BuildContext context) async {
    try {
      // Veritabanından (cafe_postlar) silme işlemi
      await Supabase.instance.client
          .from('cafe_postlar')
          .delete()
          .eq(
            'id',
            cafe.id,
          ); // UUID'yi String olarak kullanıyoruz, parse yapmıyoruz!

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post başarıyla silindi"),
            backgroundColor: Colors.green,
          ),
        );
        // Üst widget'a silme işleminin bittiğini haber ver
        if (onDelete != null) onDelete!();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Silme hatası: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sadece postun sahibi silsin istiyorsan bu kontrolü kullanabilirsin
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isOwner = cafe.user_id == currentUserId;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Satır: İsim, Silme Butonu ve Uyum Oranı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cafe.kafeAdi,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // // Silme Butonu (Sadece sahibi ise veya test için her zaman görünebilir)
                // IconButton(
                //   icon: const Icon(
                //     Icons.delete_outline,
                //     color: Colors.redAccent,
                //   ),
                //   onPressed: () {
                //     showDialog(
                //       context: context,
                //       builder: (context) => AlertDialog(
                //         title: const Text("Postu Sil"),
                //         content: const Text(
                //           "Bu kafeyi listenizden kaldırmak istediğinize emin misiniz?",
                //         ),
                //         actions: [
                //           TextButton(
                //             onPressed: () => Navigator.pop(context),
                //             child: const Text("Vazgeç"),
                //           ),
                //           ElevatedButton(
                //             style: ElevatedButton.styleFrom(
                //               backgroundColor: Colors.red,
                //             ),
                //             onPressed: () {
                //               Navigator.pop(context);
                //               _postuSil(context);
                //             },
                //             child: const Text(
                //               "Sil",
                //               style: TextStyle(color: Colors.white),
                //             ),
                //           ),
                //         ],
                //       ),
                //     );
                //   },
                // ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Uyum: %${(cafe.similarity * 100).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 2. Satır: Konum Bilgisi
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${cafe.ilceAdi} / ${cafe.semtAdi}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 3. Satır: Vibe Etiketleri
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cafe.vibeEtiketleri.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepOrange.shade100),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // 4. Satır: Haritada Gör Butonu
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MapScreen(kafeler: [cafe], odaklanilacakKafe: cafe),
                    ),
                  );
                },
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text(
                  "Haritada Gör",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
