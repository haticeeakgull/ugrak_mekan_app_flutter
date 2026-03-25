import 'package:flutter/material.dart';

// İstatistik Sütunu (Uğrak, Takipçi, Takip)
Widget buildStatColumn(String value, String label) {
  return Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );
}

// Başarı Rozetleri Bölümü
Widget buildBadgeSection() {
  final colors = [Colors.orange, Colors.blueGrey, Colors.amber];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
        child: Text(
          "Uğrak Başarıları",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: 60,
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: colors[index].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium,
              color: colors[index],
              size: 30,
            ),
          ),
        ),
      ),
    ],
  );
}
