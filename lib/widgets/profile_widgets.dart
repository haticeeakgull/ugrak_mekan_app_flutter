import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_detail_dialog.dart';

Future<List<Map<String, dynamic>>> fetchUserBadges(String userId) async {
  try {
    final supabase = Supabase.instance.client;

    debugPrint('🔍 Badge çekiliyor - User ID: $userId');

    // Hata mesajındaki 'hint' kısmına göre ilişki adını (fkey) açıkça belirttik:
    final response = await supabase
        .from('user_badges')
        .select('''
          *,
          badges!badge_id (*),
          ilce_isimli_kafeler!user_badges_cafe_id_fkey (kafe_adi)
        ''')
        .eq('user_id', userId);

    debugPrint("✅ Badge verisi başarıyla geldi! Toplam: ${response.length}");
    debugPrint("📦 Badge data: $response");
    return List<Map<String, dynamic>>.from(response);
  } catch (e, stackTrace) {
    debugPrint("❌ Badge çekme hatası: $e");
    debugPrint("📍 Stack trace: $stackTrace");
    return [];
  }
}

/// 2. Widget Fonksiyonu
Widget buildBadgeSection(String userId) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Uğrak Başarıları",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
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
                  return const Center(
                    child: Text(
                      "Henüz rozet bulunmuyor.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: userBadges.length,
                  itemBuilder: (context, index) {
                    final item = userBadges[index];

                    final badgeData = item['badges'];
                    final cafeData = item['ilce_isimli_kafeler'];

                    final String iconUrl = badgeData?['icon_url'] ?? '';
                    final String badgeTitle = badgeData?['title'] ?? 'Rozet';
                    final String? cafeName = cafeData?['kafe_adi'];

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => BadgeDetailDialog(badgeItem: item),
                        );
                      },
                      child: Container(
                        width: 85,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFFAF8F3),
                              child: iconUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        iconUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.workspace_premium,
                                            color: Color(0xFF79AE6F),
                                            size: 24,
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF79AE6F),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.workspace_premium,
                                      color: Color(0xFF79AE6F),
                                      size: 24,
                                    ),
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
                                  cafeName,
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
