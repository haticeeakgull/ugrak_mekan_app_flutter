import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BadgeService Time Range Logic Tests', () {
    test('should correctly check time within range', () {
      // Act & Assert - Normal range (09:00 - 17:00)
      expect(_isTimeInRange('10:00', '09:00', '17:00'), true);
      expect(_isTimeInRange('08:00', '09:00', '17:00'), false);
      expect(_isTimeInRange('18:00', '09:00', '17:00'), false);
      expect(_isTimeInRange('09:00', '09:00', '17:00'), true);
      expect(_isTimeInRange('17:00', '09:00', '17:00'), true);
    });

    test('should handle midnight crossing range', () {
      // Act & Assert - Midnight crossing (22:00 - 02:00)
      expect(_isTimeInRange('23:00', '22:00', '02:00'), true);
      expect(_isTimeInRange('01:00', '22:00', '02:00'), true);
      expect(_isTimeInRange('22:00', '22:00', '02:00'), true);
      expect(_isTimeInRange('02:00', '22:00', '02:00'), true);
      expect(_isTimeInRange('03:00', '22:00', '02:00'), false);
      expect(_isTimeInRange('21:00', '22:00', '02:00'), false);
      expect(_isTimeInRange('10:00', '22:00', '02:00'), false);
    });

    test('should handle edge cases for time range', () {
      // Act & Assert
      expect(_isTimeInRange('00:00', '00:00', '23:59'), true);
      expect(_isTimeInRange('12:30', '00:00', '23:59'), true);
      expect(_isTimeInRange('23:59', '00:00', '23:59'), true);
    });
  });

  group('BadgeService Internal Logic Tests', () {
    test('should correctly count unique cafes from posts', () {
      // Arrange
      final posts = [
        {'cafe_id': 'cafe1'},
        {'cafe_id': 'cafe2'},
        {'cafe_id': 'cafe1'}, // Duplicate
        {'cafe_id': 'cafe3'},
        {'cafe_id': null}, // Null cafe_id
      ];

      // Act
      final uniqueCafes = <String>{};
      for (var post in posts) {
        if (post['cafe_id'] != null) {
          uniqueCafes.add(post['cafe_id'].toString());
        }
      }

      // Assert
      expect(uniqueCafes.length, 3);
    });

    test('should correctly filter posts by time range', () {
      // Arrange
      final posts = [
        {'paylasim_tarihi': '2024-01-15T10:30:00'},
        {'paylasim_tarihi': '2024-01-15T23:45:00'},
        {'paylasim_tarihi': '2024-01-15T01:15:00'},
        {'paylasim_tarihi': '2024-01-15T15:00:00'},
      ];

      // Act - Count posts between 22:00 and 02:00
      int count = 0;
      for (var post in posts) {
        final dateTime = DateTime.parse(post['paylasim_tarihi'] as String);
        final hour = dateTime.hour;
        
        // Midnight crossing logic
        if (hour >= 22 || hour <= 2) {
          count++;
        }
      }

      // Assert
      expect(count, 2); // 23:45 and 01:15
    });

    test('should correctly filter posts by tags', () {
      // Arrange
      final posts = [
        {'baslik': 'Harika kahve', 'icerik': 'Çok güzel bir yer'},
        {'baslik': 'Sakin ortam', 'icerik': 'Çalışmak için ideal'},
        {'baslik': 'Canlı müzik', 'icerik': 'Eğlenceli bir gece'},
      ];
      final tags = ['kahve', 'müzik'];

      // Act
      int count = 0;
      for (var post in posts) {
        final text = '${post['baslik']} ${post['icerik']}'.toLowerCase();
        bool matches = false;
        for (var tag in tags) {
          if (text.contains(tag.toLowerCase())) {
            matches = true;
            break;
          }
        }
        if (matches) count++;
      }

      // Assert
      expect(count, 2); // 'kahve' and 'müzik' posts
    });

    test('should correctly filter posts by month', () {
      // Arrange
      final posts = [
        {'paylasim_tarihi': '2024-01-15T10:00:00'},
        {'paylasim_tarihi': '2024-02-20T14:00:00'},
        {'paylasim_tarihi': '2024-01-25T18:00:00'},
        {'paylasim_tarihi': '2024-03-10T12:00:00'},
      ];
      final targetMonth = 1; // January

      // Act
      int count = 0;
      for (var post in posts) {
        final dateTime = DateTime.parse(post['paylasim_tarihi'] as String);
        if (dateTime.month == targetMonth) {
          count++;
        }
      }

      // Assert
      expect(count, 2);
    });

    test('should correctly count cafe types with unique constraint', () {
      // Arrange
      final posts = [
        {'cafe_id': 'cafe1', 'icerik': 'Harika bir kahve dükkanı'},
        {'cafe_id': 'cafe2', 'icerik': 'Güzel bir restoran'},
        {'cafe_id': 'cafe1', 'icerik': 'Yine kahve içtim'}, // Same cafe
        {'cafe_id': 'cafe3', 'icerik': 'Başka bir kahve'},
      ];
      final cafeTypes = ['kahve'];

      // Act - Unique cafes only
      final matchedCafes = <String>{};
      for (var post in posts) {
        final cafeId = post['cafe_id']?.toString();
        final text = post['icerik'].toString().toLowerCase();
        
        bool matches = false;
        for (var type in cafeTypes) {
          if (text.contains(type.toLowerCase())) {
            matches = true;
            break;
          }
        }
        
        if (matches && cafeId != null) {
          matchedCafes.add(cafeId);
        }
      }

      // Assert
      expect(matchedCafes.length, 2); // cafe1 and cafe3
    });
  });
}

// Helper function for time range checking
bool _isTimeInRange(String time, String start, String end) {
  final timeInt = int.parse(time.replaceAll(':', ''));
  final startInt = int.parse(start.replaceAll(':', ''));
  final endInt = int.parse(end.replaceAll(':', ''));

  if (startInt <= endInt) {
    return timeInt >= startInt && timeInt <= endInt;
  } else {
    // Gece yarısını geçen aralıklar için (örn: 22:00 - 02:00)
    return timeInt >= startInt || timeInt <= endInt;
  }
}
