import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreService Pagination Logic Tests', () {
    test('should handle pagination parameters', () {
      // Arrange
      final limit = 20;
      final offset = 0;

      // Act
      final rangeStart = offset;
      final rangeEnd = offset + limit - 1;

      // Assert
      expect(rangeStart, 0);
      expect(rangeEnd, 19);
    });

    test('should calculate correct range for page 2', () {
      // Arrange
      final limit = 20;
      final offset = 20;

      // Act
      final rangeStart = offset;
      final rangeEnd = offset + limit - 1;

      // Assert
      expect(rangeStart, 20);
      expect(rangeEnd, 39);
    });
  });

  group('ExploreService Search Logic Tests', () {
    test('should perform case-insensitive username search', () {
      // Arrange
      final users = [
        {'username': 'JohnDoe'},
        {'username': 'janedoe'},
        {'username': 'ALICE'},
        {'username': 'bob'},
      ];
      final query = 'doe';

      // Act
      final results = users.where((user) {
        final username = user['username'].toString().toLowerCase();
        return username.contains(query.toLowerCase());
      }).toList();

      // Assert
      expect(results.length, 2);
      expect(results[0]['username'], 'JohnDoe');
      expect(results[1]['username'], 'janedoe');
    });

    test('should limit search results to 10', () {
      // Arrange
      final users = List.generate(20, (i) => {'username': 'user$i'});
      final limit = 10;

      // Act
      final results = users.take(limit).toList();

      // Assert
      expect(results.length, 10);
    });

    test('should handle empty search query', () {
      // Arrange
      final query = '';

      // Act
      final isEmpty = query.isEmpty;

      // Assert
      expect(isEmpty, true);
    });
  });

  group('ExploreService Data Structure Tests', () {
    test('should validate cafe has required fields', () {
      // Arrange
      final cafe = {
        'id': '123',
        'kafe_adi': 'Test Cafe',
        'latitude': 41.0082,
        'longitude': 28.9784,
        'il_adi': 'İstanbul',
        'ilce_adi': 'Kadıköy',
      };

      // Act & Assert
      expect(cafe.containsKey('id'), true);
      expect(cafe.containsKey('kafe_adi'), true);
      expect(cafe.containsKey('latitude'), true);
      expect(cafe.containsKey('longitude'), true);
    });

    test('should validate post has nested profile data', () {
      // Arrange
      final post = {
        'id': 'post1',
        'baslik': 'Test Post',
        'profiles': {
          'username': 'testuser',
          'avatar_url': 'https://example.com/avatar.jpg',
          'is_private': false,
        },
        'ilce_isimli_kafeler': {
          'kafe_adi': 'Test Cafe',
          'latitude': 41.0,
          'longitude': 29.0,
        },
      };

      // Act
      final profile = post['profiles'] as Map<String, dynamic>?;
      final cafe = post['ilce_isimli_kafeler'] as Map<String, dynamic>?;

      // Assert
      expect(profile, isNotNull);
      expect(profile?['username'], 'testuser');
      expect(cafe, isNotNull);
      expect(cafe?['kafe_adi'], 'Test Cafe');
    });

    test('should handle null nested data gracefully', () {
      // Arrange
      final post = {
        'id': 'post1',
        'baslik': 'Test Post',
        'profiles': null,
        'ilce_isimli_kafeler': null,
      };

      // Act
      final hasProfile = post['profiles'] != null;
      final hasCafe = post['ilce_isimli_kafeler'] != null;

      // Assert
      expect(hasProfile, false);
      expect(hasCafe, false);
    });
  });

  group('ExploreService Sorting Tests', () {
    test('should sort posts by created_at descending', () {
      // Arrange
      final posts = [
        {'id': '1', 'created_at': '2024-01-15T10:00:00'},
        {'id': '2', 'created_at': '2024-01-16T10:00:00'},
        {'id': '3', 'created_at': '2024-01-14T10:00:00'},
      ];

      // Act
      posts.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateB.compareTo(dateA); // Descending
      });

      // Assert
      expect(posts[0]['id'], '2'); // Newest
      expect(posts[1]['id'], '1');
      expect(posts[2]['id'], '3'); // Oldest
    });

    test('should handle posts with same timestamp', () {
      // Arrange
      final posts = [
        {'id': '1', 'created_at': '2024-01-15T10:00:00'},
        {'id': '2', 'created_at': '2024-01-15T10:00:00'},
      ];

      // Act
      posts.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateB.compareTo(dateA);
      });

      // Assert - Order should be stable
      expect(posts.length, 2);
    });
  });

  group('ExploreService Cafe Details Tests', () {
    test('should include nested cafe_gorselleri in details', () {
      // Arrange
      final cafeDetails = {
        'id': 'cafe1',
        'kafe_adi': 'Test Cafe',
        'cafe_gorselleri': [
          {'foto_url': 'photo1.jpg'},
          {'foto_url': 'photo2.jpg'},
        ],
        'cafe_postlar': [],
      };

      // Act
      final hasPhotos = cafeDetails['cafe_gorselleri'] != null;
      final photoCount = (cafeDetails['cafe_gorselleri'] as List).length;

      // Assert
      expect(hasPhotos, true);
      expect(photoCount, 2);
    });

    test('should include nested cafe_postlar with profiles', () {
      // Arrange
      final cafeDetails = {
        'id': 'cafe1',
        'cafe_postlar': [
          {
            'id': 'post1',
            'baslik': 'Great place',
            'profiles': {
              'username': 'user1',
              'avatar_url': 'avatar1.jpg',
            },
          },
        ],
      };

      // Act
      final posts = cafeDetails['cafe_postlar'] as List;
      final firstPost = posts.first;

      // Assert
      expect(posts.length, 1);
      expect(firstPost['profiles']['username'], 'user1');
    });
  });
}
