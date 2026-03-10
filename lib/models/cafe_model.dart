class Cafe {
  final String id;
  final String kafeAdi; // Dart içinde kafeAdi olarak kullanmak daha standarttır
  final String? user_id;
  final List<String> vibeEtiketleri;
  final String ilceAdi;
  final String semtAdi; // Tablonda semt_adi da olduğu için ekledik
  final double latitude; // Harita için kritik
  final double longitude; // Harita için kritik
  final double similarity;
  final List<String> fotograflar; // Fotoğraf URL listesi
  final List<Map<String, dynamic>> yorumlar; // Kullanıcı yorumları
  final List<Map<String, dynamic>> postlar;
  Cafe({
    required this.id,
    required this.kafeAdi,
    required this.user_id,
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

  // JSON'dan Cafe nesnesine dönüştürme
  factory Cafe.fromJson(Map<String, dynamic> json) {
    return Cafe(
      id: json['id']?.toString() ?? '',
      kafeAdi: json['kafe_adi'] ?? 'Bilinmeyen Mekan',
      user_id: json['user_id'],
      ilceAdi: json['ilce_adi'] ?? 'İlçe Belirtilmemiş',
      semtAdi: json['semt_adi'] ?? 'Semt Belirtilmemiş',
      vibeEtiketleri: List<String>.from(json['vibe_etiketleri'] ?? []),
      // Koordinatları double'a güvenli bir şekilde çeviriyoruz
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      fotograflar: List<String>.from(json['fotograflar'] ?? []),
      yorumlar: List<Map<String, dynamic>>.from(json['yorumlar'] ?? []),
      postlar: List<Map<String, dynamic>>.from(json['postlar'] ?? []),
    );
  }
}
