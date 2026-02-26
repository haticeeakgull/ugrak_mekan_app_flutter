class Cafe {
  final String id;
  final String name;
  final List<String> vibeTags;
  final double similarity;

  Cafe({
    required this.id,
    required this.name,
    required this.vibeTags,
    required this.similarity,
  });

  // JSON'dan Cafe nesnesine dönüştürme (React Native'deki item gibi)
  factory Cafe.fromJson(Map<String, dynamic> json) {
    return Cafe(
      id: json['id'] ?? '',
      name: json['kafe_adi'] ?? 'Bilinmeyen Mekan',
      vibeTags: List<String>.from(json['vibe_etiketleri'] ?? []),
      similarity: (json['similarity'] ?? 0).toDouble(),
    );
  }
}
