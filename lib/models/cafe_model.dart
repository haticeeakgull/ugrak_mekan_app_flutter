class Cafe {
  final String id;
  final String name;
  final List<String> vibeTags;
  final String district;
  final double similarity;

  Cafe({
    required this.id,
    required this.name,
    required this.vibeTags,
    required this.district,
    required this.similarity,
  });

  // JSON'dan Cafe nesnesine dönüştürme
  factory Cafe.fromJson(Map<String, dynamic> json) {
    return Cafe(
      id: json['id'] ?? '',
      name: json['kafe_adi'] ?? 'Bilinmeyen Mekan',
      district: json['ilce_adi'] ?? 'Semt Belirtilmemiş',
      vibeTags: List<String>.from(json['vibe_etiketleri'] ?? []),
      similarity: (json['similarity'] ?? 0).toDouble(),
    );
  }
}
