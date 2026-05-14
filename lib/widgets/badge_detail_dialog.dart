import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BadgeDetailDialog extends StatelessWidget {
  final Map<String, dynamic> badgeItem;

  const BadgeDetailDialog({
    super.key,
    required this.badgeItem,
  });

  @override
  Widget build(BuildContext context) {
    final badgeData = badgeItem['badges'];
    final cafeData = badgeItem['ilce_isimli_kafeler'];
    
    final String iconUrl = badgeData?['icon_url'] ?? '';
    final String title = badgeData?['title'] ?? 'Rozet';
    final String description = badgeData?['description'] ?? '';
    final String rarity = badgeData?['rarity'] ?? 'common';
    final int points = badgeData?['points'] ?? 0;
    final String? cafeName = cafeData?['kafe_adi'];
    final DateTime? earnedAt = badgeItem['created_at'] != null
        ? DateTime.parse(badgeItem['created_at'])
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: const Color(0xFFFAF8F3),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge İkonu
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: _getRarityColor(rarity).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: iconUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        iconUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.workspace_premium,
                            color: _getRarityColor(rarity),
                            size: 60,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.workspace_premium,
                      color: _getRarityColor(rarity),
                      size: 60,
                    ),
            ),
            const SizedBox(height: 20),

            // Rarity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getRarityColor(rarity).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getRarityColor(rarity),
                  width: 1.5,
                ),
              ),
              child: Text(
                _getRarityText(rarity),
                style: TextStyle(
                  color: _getRarityColor(rarity),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Başlık
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF346739),
              ),
            ),
            const SizedBox(height: 8),

            // Puan
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.stars,
                  color: Color(0xFF79AE6F),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '$points Puan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF79AE6F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Açıklama
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ),

            // Kafe Bilgisi (varsa)
            if (cafeName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF346739).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF346739),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        cafeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF346739),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Kazanılma Tarihi
            if (earnedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Kazanıldı: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(earnedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Kapat Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF346739),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kapat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFFD700); // Altın
      case 'epic':
        return const Color(0xFF9B59B6); // Mor
      case 'rare':
        return const Color(0xFF3498DB); // Mavi
      case 'uncommon':
        return const Color(0xFF2ECC71); // Yeşil
      default:
        return const Color(0xFF95A5A6); // Gri
    }
  }

  String _getRarityText(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return 'Efsanevi';
      case 'epic':
        return 'Epik';
      case 'rare':
        return 'Nadir';
      case 'uncommon':
        return 'Az Bulunur';
      default:
        return 'Yaygın';
    }
  }
}
