import 'package:flutter/material.dart';
import '../models/cafe_model.dart';

class CafeCard extends StatelessWidget {
  final Cafe cafe;

  const CafeCard({super.key, required this.cafe});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cafe.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: cafe.vibeTags
                  .map(
                    (tag) => Text(
                      '#$tag',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Uyum: %${(cafe.similarity * 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
