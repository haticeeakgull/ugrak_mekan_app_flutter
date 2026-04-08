import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Uğrak Mekan uygulaması için Cafe model sınıfı.
/// Artık Google Maps'in yerleşik kümeleme özelliğini kullandığımız için
/// herhangi bir sınıftan (ClusterItem vb.) türetilmesine gerek yoktur.
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
  final List<String> fotograflar;
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
    required this.fotograflar,
    required this.yorumlar,
    required this.postlar,
  });

  /// Harita üzerinde işaretçi (Marker) oluştururken kolaylık sağlaması için getter.
  LatLng get location => LatLng(latitude, longitude);

  /// Supabase veya yerel JSON verisini model nesnesine dönüştürür.
  factory Cafe.fromJson(Map<String, dynamic> json) {
    // Postların farklı tablo/key isimleriyle gelme ihtimalini yönetiyoruz.
    final postList = json['cafe_postlar'] ?? json['postlar'] ?? [];

    return Cafe(
      id: json['id']?.toString() ?? '',
      kafeAdi: json['kafe_adi'] ?? 'Bilinmeyen Mekan',
      userId: json['user_id']?.toString(),
      // 'ilce_adi' yoksa 'ilce' kolonuna bakıyoruz.
      ilceAdi: json['ilce_adi'] ?? json['ilce'] ?? 'İlçe Belirtilmemiş',
      semtAdi: json['semt_adi'] ?? 'Semt Belirtilmemiş',
      vibeEtiketleri: List<String>.from(json['vibe_etiketleri'] ?? []),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      fotograflar: List<String>.from(json['fotograflar'] ?? []),
      yorumlar: List<Map<String, dynamic>>.from(json['yorumlar'] ?? []),
      postlar: List<Map<String, dynamic>>.from(postList),
    );
  }

  /// Modeli tekrar JSON formatına dönüştürmek için kullanılır.
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
      'fotograflar': fotograflar,
      'yorumlar': yorumlar,
      'postlar': postlar,
    };
  }
}
