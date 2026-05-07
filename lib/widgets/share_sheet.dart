import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/collection_service.dart';
import 'collection_share_preview.dart';

void showAdvancedShareSheet(
  BuildContext context,
  String colId,
  String colName, {
  String? coverImageUrl,
  List<String>? cafePhotos,
  String? ownerUsername,
  String? ownerAvatarUrl,
  int? cafeCount,
  bool? isPublic,
}) {
  debugPrint('🔍 Share Sheet Açıldı:');
  debugPrint('   Collection ID: $colId');
  debugPrint('   Collection Name: $colName');
  debugPrint('   Cafe Count: $cafeCount');
  
  final collectionService = CollectionService();
  final supabase = Supabase.instance.client;
  final GlobalKey previewKey = GlobalKey();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Başlık
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              "Koleksiyonu Paylaş",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Preview kartı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: RepaintBoundary(
              key: previewKey,
              child: CollectionSharePreview(
                collectionName: colName,
                coverImageUrl: coverImageUrl,
                cafePhotos: cafePhotos ?? [],
                ownerUsername: ownerUsername ?? 'Kullanıcı',
                ownerAvatarUrl: ownerAvatarUrl,
                cafeCount: cafeCount ?? 0,
                isPublic: isPublic ?? true,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Paylaşım seçenekleri - Sabit layout (scroll yok)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kart ve link ile paylaş (WhatsApp, Instagram, diğerleri)
                  _ShareOption(
                    icon: Icons.share,
                    iconColor: const Color(0xFF346739),
                    title: 'Kart ve Link ile Paylaş',
                    subtitle: 'WhatsApp, Instagram ve diğer uygulamalar',
                    onTap: () async {
                      final imageBytes = await captureCollectionPreview(previewKey);
                      if (imageBytes != null) {
                        final imagePath = await saveCollectionPreviewToFile(imageBytes);
                        if (imagePath != null) {
                          await Share.shareXFiles(
                            [XFile(imagePath)],
                            text: '$colName koleksiyonuma göz at!\nhttps://haticeeakgull.github.io/?koleksiyonId=$colId',
                          );
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Sadece link paylaş
                  _ShareOption(
                    icon: Icons.link,
                    iconColor: Colors.blue,
                    title: 'Sadece Link Paylaş',
                    subtitle: 'Metin olarak paylaş',
                    onTap: () {
                      Share.share(
                        '$colName koleksiyonuma göz at!\nhttps://haticeeakgull.github.io/?koleksiyonId=$colId',
                      );
                      Navigator.pop(context);
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Uygulama içi paylaşım başlığı
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Uygulama İçinde Paylaş',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  
                  // Arkadaşlara gönder
                  FutureBuilder<List<dynamic>>(
                    future: supabase
                        .from('profiles')
                        .select()
                        .neq('id', supabase.auth.currentUser!.id)
                        .limit(5),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.data!.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Henüz arkadaşın yok',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      
                      return Column(
                        children: snapshot.data!.map((friend) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: friend['avatar_url'] != null
                                    ? NetworkImage(friend['avatar_url'])
                                    : null,
                                child: friend['avatar_url'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                friend['username'] ?? 'Kullanıcı',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF346739),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  try {
                                    debugPrint('🚀 Arkadaşa gönderiliyor...');
                                    debugPrint('   Friend ID: ${friend['id']}');
                                    debugPrint('   Friend Username: ${friend['username']}');
                                    debugPrint('   Collection ID: $colId');
                                    debugPrint('   Collection Name: $colName');
                                    
                                    await collectionService.sendToFriend(
                                      friend['id'],
                                      colId,
                                      colName,
                                    );
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '${friend['username']} kullanıcısına gönderildi! ✨',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF346739),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('❌ Gönderim hatası: $e');
                                    debugPrint('   Stack trace: ${StackTrace.current}');
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Gönderilirken bir hata oluştu: $e',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Gönder'),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
