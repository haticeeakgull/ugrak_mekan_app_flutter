import 'package:flutter/material.dart';
import '../models/cafe_model.dart';
import '../views/map_screen.dart'; // Harita ekranını import ediyoruz

class CafeCard extends StatelessWidget {
  final Cafe cafe;

  const CafeCard({super.key, required this.cafe});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3, // Biraz daha belirgin bir gölge
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Satır: İsim ve Uyum Oranı
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

            // 2. Satır: Konum Bilgisi (İlçe / Semt)
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                // Burayı Expanded içine alıyoruz ki sığmayan metin aşağı kaymasın veya hata vermesin
                Expanded(
                  child: Text(
                    "${cafe.ilceAdi} / ${cafe.semtAdi}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    overflow: TextOverflow.ellipsis, // Sığmazsa "..." koyar
                    maxLines: 1, // Tek satırda tutar
                  ),
                ),
              ],
            ),

            // 3. Satır: Vibe Etiketleri (Modern Chip Görünümü)
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
                  // Harita ekranına sadece bu kafeyi içeren liste ile git
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
