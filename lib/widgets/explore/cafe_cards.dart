import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/map_explore_controller.dart';
import '../../models/cafe_model.dart';
import '../cafe_detail_sheet.dart';

class CafeCardsWidget extends StatelessWidget {
  final MapExploreController controller;
  const CafeCardsWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 25, bottom: 10),
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                child: const Icon(Icons.close, color: Colors.black),
                onPressed: () => controller.toggleCafeCards(false),
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: PageView.builder(
              controller: controller.pageController,
              itemCount: controller.kafeler.length,
              onPageChanged: (index) {
                controller.onPageChanged(index);
              },
              itemBuilder: (context, index) =>
                  CafeCardItem(cafeData: controller.kafeler[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class CafeCardItem extends StatefulWidget {
  final dynamic cafeData;
  const CafeCardItem({super.key, required this.cafeData});

  @override
  State<CafeCardItem> createState() => _CafeCardItemState();
}

class _CafeCardItemState extends State<CafeCardItem> {
  List<String> _photos = [];
  bool _isLoadingPhotos = true;
  int _currentPhotoIndex = 0;
  final PageController _photoPageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchCafePhotos();
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
  }

  /// Kafenin tüm fotoğraflarını getir
  /// Öncelik: Kullanıcı postları → Google fotoğrafları → cafe_gorseller
  Future<void> _fetchCafePhotos() async {
    if (!mounted) return;
    
    try {
      final cafe = Cafe.fromJson(widget.cafeData);
      final supabase = Supabase.instance.client;
      List<String> allPhotos = [];

      debugPrint('📸 Fotoğraflar çekiliyor: ${cafe.kafeAdi} (ID: ${cafe.id})');

      // 1. ADIM: cafe_postlar (Kullanıcı postları - Öncelik)
      final postResponse = await supabase
          .from('cafe_postlar')
          .select('foto_url')
          .eq('cafe_id', cafe.id)
          .order('created_at', ascending: false);

      if (postResponse != null && postResponse.isNotEmpty) {
        for (var post in postResponse) {
          if (post['foto_url'] != null) {
            allPhotos.add(post['foto_url']);
          }
        }
        debugPrint('✅ ${allPhotos.length} kullanıcı postu bulundu');
      }

      // 2. ADIM: cafe_fotograflar (Supabase Storage URL'leri)
      final cafePhotosResponse = await supabase
          .from('cafe_fotograflar')
          .select('foto_url')
          .eq('cafe_id', cafe.id);

      if (cafePhotosResponse != null && cafePhotosResponse.isNotEmpty) {
        for (var photo in cafePhotosResponse) {
          if (photo['foto_url'] != null && !allPhotos.contains(photo['foto_url'])) {
            allPhotos.add(photo['foto_url']);
          }
        }
        debugPrint('✅ Toplam ${allPhotos.length} fotoğraf (cafe_fotograflar dahil)');
      }

      // 3. ADIM: cafe_gorseller (Yedek - cafe modelinden gelen)
      if (allPhotos.isEmpty && cafe.gorseller.isNotEmpty) {
        cafe.gorseller.sort(
          (a, b) => (b['oncelik_sirasi'] ?? 0).compareTo(a['oncelik_sirasi'] ?? 0),
        );
        for (var gorsel in cafe.gorseller) {
          if (gorsel['foto_url'] != null) {
            allPhotos.add(gorsel['foto_url']);
          }
        }
        debugPrint('✅ ${allPhotos.length} cafe_gorseller fotoğrafı bulundu');
      }

      if (mounted) {
        setState(() {
          _photos = allPhotos;
          _isLoadingPhotos = false;
        });
        debugPrint('✅ Toplam ${_photos.length} fotoğraf yüklendi');
      }
    } catch (e) {
      debugPrint('❌ Fotoğraf çekme hatası: $e');
      if (mounted) {
        setState(() {
          _photos = [];
          _isLoadingPhotos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cafe = Cafe.fromJson(widget.cafeData);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fotoğraf Galerisi
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              child: _isLoadingPhotos
                  ? Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF346739),
                        ),
                      ),
                    )
                  : _photos.isEmpty
                      ? Container(
                          color: Colors.grey[100],
                          child: const Icon(
                            Icons.local_cafe,
                            size: 50,
                            color: Colors.grey,
                          ),
                        )
                      : Stack(
                          children: [
                            // Fotoğraf PageView
                            PageView.builder(
                              controller: _photoPageController,
                              itemCount: _photos.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPhotoIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return Image.network(
                                  _photos[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[100],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            // Fotoğraf sayısı göstergesi
                            if (_photos.length > 1)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_currentPhotoIndex + 1}/${_photos.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // Nokta göstergeleri
                            if (_photos.length > 1)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _photos.length,
                                    (index) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPhotoIndex == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ),
          // Kafe Bilgileri
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cafe.kafeAdi,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${cafe.ilceAdi} • Cafe",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CafeDetailSheet(cafe: cafe),
                    ),
                    child: const Text(
                      "Tüm Detayları Gör →",
                      style: TextStyle(
                        color: Color(0xFF346739),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
