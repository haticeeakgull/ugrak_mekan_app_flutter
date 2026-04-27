import 'package:flutter/material.dart';

const Color _deepGreen = Color(0xFF346739);
const Color _midGreen = Color(0xFF79AE6F);

class CollectionCard extends StatelessWidget {
  final dynamic collection;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final Function(String action) onMenuSelected;

  const CollectionCard({
    super.key,
    required this.collection,
    required this.isMe,
    required this.onTap,
    required this.onShare,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPublic = collection['is_public'] ?? true;
    final bool isSaved = collection['is_saved'] ?? false; // Kaydedilmiş mi?
    final String name = collection['isim'] ?? 'Koleksiyon';
    final String? ownerUsername = collection['profiles']?['username']; // Koleksiyon sahibi
    final String? coverImage = collection['cover_image_url'];
    final dynamic cafePhotosRaw = collection['cafe_photos'];
    
    // cafe_photos'u List<String>'e dönüştür
    List<String> cafePhotos = [];
    if (cafePhotosRaw != null) {
      if (cafePhotosRaw is List) {
        cafePhotos = cafePhotosRaw.map((e) => e.toString()).toList();
      }
    }
    
    // Debug
    print('   Koleksiyon kartı: $name');
    print('   Cover: $coverImage');
    print('   Fotolar: $cafePhotos');
    
    // Cover image varsa onu kullan, yoksa kafe fotolarını kullan
    final bool hasCoverImage = coverImage != null && coverImage.isNotEmpty;
    final bool hasCafePhotos = cafePhotos.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _deepGreen.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Arka plan: cover image, kafe fotoları grid, veya gradient
              if (hasCoverImage)
                Positioned.fill(
                  child: Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPhotoGrid(cafePhotos),
                  ),
                )
              else if (hasCafePhotos)
                Positioned.fill(child: _buildPhotoGrid(cafePhotos))
              else
                Positioned.fill(child: _buildDefaultBackground()),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // İçerik
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst kısım: menü butonları
                    if (isMe)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _IconBtn(
                            icon: Icons.ios_share_rounded,
                            onTap: onShare,
                          ),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.more_vert_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onSelected: onMenuSelected,
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'privacy',
                                child: Row(
                                  children: [
                                    Icon(
                                      isPublic
                                          ? Icons.lock_rounded
                                          : Icons.public_rounded,
                                      size: 16,
                                      color: _deepGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPublic ? 'Gizle' : 'Herkese Aç',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _deepGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sil',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const Spacer(),
                    // Alt kısım: isim ve badge
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Kaydedilmiş koleksiyonsa sahibini göster
                        if (isSaved && ownerUsername != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '@$ownerUsername',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        // Public/Private badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPublic
                                    ? Icons.public_rounded
                                    : Icons.lock_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPublic ? 'Herkese açık' : 'Gizli',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos) {
    if (photos.isEmpty) {
      return _buildDefaultBackground();
    }

    print('📸 _buildPhotoGrid: ${photos.length} foto gösteriliyor');
    photos.forEach((url) => print('   - $url'));

    // 1 foto: tam ekran
    if (photos.length == 1) {
      return Image.network(
        photos[0],
        fit: BoxFit.cover,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        errorBuilder: (_, error, ___) {
          print('❌ Foto yüklenemedi: ${photos[0]}');
          print('   Hata: $error');
          return _buildDefaultBackground();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Foto yüklendi: ${photos[0]}');
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        },
      );
    }

    // 2-4 foto: grid layout
    final int photoCount = photos.length > 4 ? 4 : photos.length;
    
    return Row(
      children: [
        // Sol taraf: ilk foto (büyük)
        Expanded(
          child: Image.network(
            photos[0],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: _midGreen.withOpacity(0.5),
            ),
          ),
        ),
        // Sağ taraf: diğer fotolar (küçük, dikey)
        if (photoCount > 1)
          Expanded(
            child: Column(
              children: [
                for (int i = 1; i < photoCount; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: 1,
                        top: i > 1 ? 1 : 0,
                      ),
                      child: Image.network(
                        photos[i],
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
            _midGreen.withOpacity(0.6),
            _deepGreen.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.bookmark_rounded,
          size: 60,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
