import 'package:google_maps_flutter/google_maps_flutter.dart';

class Cafe {
  final String id;
  final String kafeAdi;
  final String? userId;
  final List<String> vibeEtiketleri;
  final String ilceAdi;
  final String semtAdi;
  final double latitude;
  final double longitude;
  final double similarity;
  // String listesi yerine artık detaylı bir Map listesi tutuyoruz
  final List<Map<String, dynamic>> gorseller;
  final List<Map<String, dynamic>> yorumlar;
  final List<Map<String, dynamic>> postlar;

  Cafe({
    required this.id,
    required this.kafeAdi,
    required this.userId,
    required this.vibeEtiketleri,
    required this.ilceAdi,
    required this.semtAdi,
    required this.latitude,
    required this.longitude,
    required this.similarity,
    required this.gorseller,
    required this.yorumlar,
    required this.postlar,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory Cafe.fromJson(Map<String, dynamic> json) {
    // 1. Yeni tablodan gelen veriyi alıyoruz
    final gorselList = List<Map<String, dynamic>>.from(
      json['cafe_gorselleri'] ?? [],
    );

    // 2. Eğer yeni tablo boşsa (henüz geçiş aşamasındaysan) eski 'fotograflar'ı Map'e çevirerek koruyalım
    if (gorselList.isEmpty && json['fotograflar'] != null) {
      for (var url in json['fotograflar']) {
        gorselList.add({
          'foto_url': url,
          'kaynak_tipi': 'official',
          'oncelik_sirasi': 0,
        });
      }
    }

    return Cafe(
      id: json['id']?.toString() ?? '',
      kafeAdi: json['kafe_adi'] ?? 'Bilinmeyen Mekan',
      userId: json['user_id']?.toString(),
      ilceAdi: json['ilce_adi'] ?? json['ilce'] ?? 'İlçe Belirtilmemiş',
      semtAdi: json['semt_adi'] ?? 'Semt Belirtilmemiş',
      vibeEtiketleri: List<String>.from(json['vibe_etiketleri'] ?? []),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      gorseller: gorselList, // Artık burası zengin bir liste
      yorumlar: List<Map<String, dynamic>>.from(json['yorumlar'] ?? []),
      postlar: List<Map<String, dynamic>>.from(
        json['cafe_postlar'] ?? json['postlar'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kafe_adi': kafeAdi,
      'user_id': userId,
      'vibe_etiketleri': vibeEtiketleri,
      'ilce_adi': ilceAdi,
      'semt_adi': semtAdi,
      'latitude': latitude,
      'longitude': longitude,
      'similarity': similarity,
      'cafe_gorselleri': gorseller,
      'yorumlar': yorumlar,
      'postlar': postlar,
    };
  }
}
