import 'package:flutter/material.dart';
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
              onPageChanged: (index) => controller.onMarkerTapped(index),
              itemBuilder: (context, index) =>
                  _buildCard(context, controller.kafeler[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, dynamic cafeData) {
    final cafe = Cafe.fromJson(cafeData);
    String? kapakFoto;
    if (cafe.gorseller.isNotEmpty) {
      cafe.gorseller.sort(
        (a, b) =>
            (b['oncelik_sirasi'] ?? 0).compareTo(a['oncelik_sirasi'] ?? 0),
      );
      kapakFoto = cafe.gorseller[0]['foto_url'];
    }

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
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              child: kapakFoto != null
                  ? Image.network(
                      kapakFoto,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.local_cafe,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
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
                        color: Colors.deepOrange,
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
