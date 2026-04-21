import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> fetchUserBadges(String userId) async {
  try {
    final supabase = Supabase.instance.client;

    // Hata mesajındaki 'hint' kısmına göre ilişki adını (fkey) açıkça belirttik:
    final response = await supabase
        .from('user_badges')
        .select('''
          *,
          badges!badge_id (*),
          ilce_isimli_kafeler!user_badges_cafe_id_fkey (kafe_adi)
        ''')
        .eq('user_id', userId);

    debugPrint("Veri başarıyla geldi!");
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint("Rozet hatası: $e");
    return [];
  }
}

/// 2. Widget Fonksiyonu
Widget buildBadgeSection(String userId) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
        child: Text(
          "Uğrak Başarıları",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      SizedBox(
        height: 115,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchUserBadges(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final userBadges = snapshot.data ?? [];
            if (userBadges.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(left: 20.0),
                child: Text(
                  "Henüz rozet bulunmuyor.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              );
            }

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: userBadges.length,
              itemBuilder: (context, index) {
                final item = userBadges[index];

                final badgeData = item['badges'];
                // Tablo adı değiştiği için buradaki key de değişti:
                final cafeData = item['ilce_isimli_kafeler'];

                final String iconUrl = badgeData?['icon_url'] ?? '';
                final String badgeTitle = badgeData?['title'] ?? 'Rozet';
                // Senin tablonda kolon adı 'kafe_adi' olduğu için onu kullanıyoruz:
                final String? cafeName = cafeData?['kafe_adi'];

                return Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFF2EDC2),
                        backgroundImage: iconUrl.isNotEmpty
                            ? NetworkImage(iconUrl)
                            : null,
                        child: iconUrl.isEmpty
                            ? const Icon(
                                Icons.workspace_premium,
                                color: const Color(0xFF79AE6F),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badgeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cafeName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "($cafeName)",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}
