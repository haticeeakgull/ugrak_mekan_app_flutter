import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/cafe_model.dart';

class MapScreen extends StatelessWidget {
  final List<Cafe> kafeler; // Haritada görünecek tüm kafeler
  final Cafe? odaklanilacakKafe; // Eğer bir kafeye tıklandıysa ona zoom yap

  const MapScreen({super.key, required this.kafeler, this.odaklanilacakKafe});

  @override
  Widget build(BuildContext context) {
    print(
      "Harita yükleniyor. Koordinatlar: ${odaklanilacakKafe?.latitude}, ${odaklanilacakKafe?.longitude}",
    );
    return Scaffold(
      appBar: AppBar(title: const Text("Mekan Keşfi")),
      body: FlutterMap(
        options: MapOptions(
          // Başlangıç merkezi: Odak kafe varsa o, yoksa Ankara merkezi
          initialCenter: odaklanilacakKafe != null
              ? LatLng(
                  odaklanilacakKafe!.latitude,
                  odaklanilacakKafe!.longitude,
                )
              : const LatLng(39.9334, 32.8597),
          initialZoom: odaklanilacakKafe != null ? 15.0 : 12.0,
        ),
        children: [
          // 1. KATMAN: Harita Görseli (Zemin)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: "com.example.ugrak_mekan_app",
          ),

          // 2. KATMAN: Kafelerin İşaretçileri
          MarkerLayer(
            markers: kafeler
                .map(
                  (kafe) => Marker(
                    point: LatLng(kafe.latitude, kafe.longitude),
                    width: 50,
                    height: 50,
                    child: IconButton(
                      icon: const Icon(
                        Icons.location_on,
                        color: Colors.deepOrange,
                        size: 35,
                      ),
                      onPressed: () => _detayGoster(context, kafe),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _detayGoster(BuildContext context, Cafe kafe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kafe.kafeAdi,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Semt: ${kafe.semtAdi}"),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tamam"),
            ),
          ],
        ),
      ),
    );
  }
}
