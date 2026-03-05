import 'package:flutter/material.dart';
import '../models/cafe_model.dart';

class CafeDetailSheet extends StatefulWidget {
  final Cafe cafe;
  const CafeDetailSheet({super.key, required this.cafe});

  @override
  State<CafeDetailSheet> createState() => _CafeDetailSheetState();
}

class _CafeDetailSheetState extends State<CafeDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, // İlk açılış yüksekliğini biraz artırdık
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // 1. Sabit Başlık Alanı (Kaydırılmayan kısım)
              _buildHeaderHandle(),

              // 2. Kaydırılabilir Ana İçerik
              Expanded(
                child: NestedScrollView(
                  controller:
                      scrollController, // Ana kaydırıcıyı buraya bağladık
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.cafe.kafeAdi,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: widget.cafe.vibeEtiketleri
                                    .map(
                                      (v) => Chip(
                                        label: Text("#$v"),
                                        backgroundColor: Colors.orange.shade50,
                                        side: BorderSide.none,
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Fotoğraflar",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildPhotoGallery(),
                            ],
                          ),
                        ),
                      ),
                      // TabBar Sliver'ı - Yukarı kayınca yapışır (pinned: true)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            labelColor: Colors.deepOrange,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.deepOrange,
                            indicatorWeight: 3,
                            tabs: const [
                              Tab(text: "Yorumlar"),
                              Tab(text: "Öneriler"),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCommentList(widget.cafe.yorumlar),
                      _buildPostList(widget.cafe.postlar),
                    ],
                  ),
                ),
              ),

              // 3. Sabit Yorum Yazma Alanı
              _buildCommentInputArea(),
            ],
          ),
        );
      },
    );
  }

  // Tasarımı iyileştirilmiş yorum listesi
  Widget _buildCommentList(List comments) {
    // Buradaki 'comments' artık senin Python ile aktardığın
    // 'cafe_yorumlar' tablosundan gelen liste olmalı.

    if (comments.isEmpty) return const Center(child: Text("Yorum bulunamadı."));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true, // Scroll sorununu önler
      physics: const NeverScrollableScrollPhysics(), // Ana kaydırıcıyı kullanır
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final yorum = comments[index];
        print("Gelen yorum verisi: ${yorum.toString()}");
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.orange.shade50,
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    yorum['kullanici_adi'] ?? 'Misafir',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                yorum['mesaj'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Fotoğraf galerisi (Hata resmini kaldırdık, temiz hale getirdik)
  Widget _buildPhotoGallery() {
    return SizedBox(
      height: 140,
      child: widget.cafe.fotograflar.isEmpty
          ? Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                  size: 40,
                ),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.cafe.fotograflar.length,
              itemBuilder: (context, index) => Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(widget.cafe.fotograflar[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildCommentInputArea() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 15,
        left: 15,
        right: 15,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Bu mekan hakkında ne düşünüyorsun?",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            onPressed: () {},
            backgroundColor: Colors.deepOrange,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(List posts) =>
      const Center(child: Text("Henüz bir öneri paylaşılmamış."));
}

// TabBar'ın Sliver içinde sabit kalmasını sağlayan yardımcı sınıf
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: Colors.white, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
