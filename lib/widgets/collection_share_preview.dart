import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

const Color _deepGreen = Color(0xFF346739);
const Color _midGreen = Color(0xFF79AE6F);
const Color _lightCream = Color(0xFFFAF8F3);

/// Koleksiyon paylaşım preview kartı
/// Bu widget'ı screenshot olarak kaydedip paylaşabiliriz
class CollectionSharePreview extends StatelessWidget {
  final String collectionName;
  final String? coverImageUrl;
  final List<String> cafePhotos;
  final String ownerUsername;
  final String? ownerAvatarUrl;
  final int cafeCount;
  final bool isPublic;

  const CollectionSharePreview({
    super.key,
    required this.collectionName,
    this.coverImageUrl,
    required this.cafePhotos,
    required this.ownerUsername,
    this.ownerAvatarUrl,
    required this.cafeCount,
    this.isPublic = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst kısım: Fotoğraf
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: _buildImageSection(),
            ),
          ),
          
          // Alt kısım: Bilgiler
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Koleksiyon ismi
                  Text(
                    collectionName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _deepGreen,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Kafe sayısı
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _midGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: _deepGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$cafeCount Kafe',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _deepGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isPublic)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _deepGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.public,
                                size: 14,
                                color: _deepGreen,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Herkese Açık',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _deepGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Kullanıcı bilgisi
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _midGreen.withOpacity(0.2),
                        backgroundImage: ownerAvatarUrl != null
                            ? NetworkImage(ownerAvatarUrl!)
                            : null,
                        child: ownerAvatarUrl == null
                            ? const Icon(
                                Icons.person,
                                color: _deepGreen,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$ownerUsername',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _deepGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Uğrak Mekan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _deepGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    // Cover image varsa onu kullan
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            coverImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPhotoGrid(),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // Kafe fotoları varsa grid göster
    if (cafePhotos.isNotEmpty) {
      return _buildPhotoGrid();
    }
    
    // Hiçbiri yoksa default gradient
    return _buildDefaultBackground();
  }

  Widget _buildPhotoGrid() {
    if (cafePhotos.isEmpty) {
      return _buildDefaultBackground();
    }

    // 1 foto: tam ekran
    if (cafePhotos.length == 1) {
      return Image.network(
        cafePhotos[0],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultBackground(),
      );
    }

    // 2-4 foto: grid layout
    final photoCount = cafePhotos.length > 4 ? 4 : cafePhotos.length;
    
    return Row(
      children: [
        // Sol: ilk foto (büyük)
        Expanded(
          child: Image.network(
            cafePhotos[0],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: _midGreen.withOpacity(0.5),
            ),
          ),
        ),
        // Sağ: diğer fotolar
        if (photoCount > 1)
          Expanded(
            child: Column(
              children: [
                for (int i = 1; i < photoCount; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: 2,
                        top: i > 1 ? 2 : 0,
                      ),
                      child: Image.network(
                        cafePhotos[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _midGreen.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _midGreen,
            _deepGreen,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.bookmark_rounded,
          size: 80,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}

/// Screenshot helper fonksiyonu
Future<Uint8List?> captureCollectionPreview(GlobalKey key) async {
  try {
    RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Screenshot hatası: $e');
    return null;
  }
}

/// Screenshot'ı dosyaya kaydet
Future<String?> saveCollectionPreviewToFile(Uint8List imageBytes) async {
  try {
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/collection_share_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(imageBytes);
    return imagePath;
  } catch (e) {
    debugPrint('Dosya kaydetme hatası: $e');
    return null;
  }
}
