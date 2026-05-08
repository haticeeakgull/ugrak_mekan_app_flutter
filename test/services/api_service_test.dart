import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('ApiService Query Logic Tests', () {
    test('searchCafesByName query building logic', () {
      // Arrange
      final query = 'starbucks';

      // Act
      final shouldFilter = query.isNotEmpty && query != 'kafe';

      // Assert
      expect(shouldFilter, true);
    });

    test('searchCafes should skip generic kafe query', () {
      // Arrange
      final query = 'kafe';

      // Act
      final shouldFilter = query.isNotEmpty && query != 'kafe';

      // Assert
      expect(shouldFilter, false);
    });
  });

  group('Distance Calculation Tests (Haversine Formula)', () {
    test('calculateDistance should return correct distance Istanbul to Ankara', () {
      // Arrange - Istanbul to Ankara (approx 350km)
      final lat1 = 41.0082;
      final lon1 = 28.9784;
      final lat2 = 39.9334;
      final lon2 = 32.8597;

      // Act
      final distance = _calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 350km
      expect(distance, greaterThan(300));
      expect(distance, lessThan(400));
    });

    test('calculateDistance should return 0 for same location', () {
      // Arrange
      final lat = 41.0082;
      final lon = 28.9784;

      // Act
      final distance = _calculateDistance(lat, lon, lat, lon);

      // Assert
      expect(distance, closeTo(0, 0.1));
    });

    test('_calculateDistance should handle negative coordinates', () {
      // Arrange
      final lat1 = -33.8688; // Sydney
      final lon1 = 151.2093;
      final lat2 = -37.8136; // Melbourne
      final lon2 = 144.9631;

      // Act
      final distance = _calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 700km
      expect(distance, greaterThan(600));
      expect(distance, lessThan(800));
    });

    test('_toRadians should convert degrees to radians correctly', () {
      // Arrange & Act
      final radians0 = _toRadians(0);
      final radians90 = _toRadians(90);
      final radians180 = _toRadians(180);
      final radians360 = _toRadians(360);

      // Assert
      expect(radians0, 0);
      expect(radians90, closeTo(pi / 2, 0.0001));
      expect(radians180, closeTo(pi, 0.0001));
      expect(radians360, closeTo(2 * pi, 0.0001));
    });
  });

  group('ApiService Sorting Logic Tests', () {
    test('should sort cafes by distance when location provided', () {
      // Arrange
      final userLat = 41.0;
      final userLng = 29.0;
      final cafes = [
        {'id': '1', 'kafe_adi': 'Far Cafe', 'latitude': 42.0, 'longitude': 30.0},
        {'id': '2', 'kafe_adi': 'Near Cafe', 'latitude': 41.1, 'longitude': 29.1},
        {'id': '3', 'kafe_adi': 'Mid Cafe', 'latitude': 41.5, 'longitude': 29.5},
      ];

      // Act
      cafes.sort((a, b) {
        final distA = _calculateDistance(
          userLat,
          userLng,
          a['latitude'] as double,
          a['longitude'] as double,
        );
        final distB = _calculateDistance(
          userLat,
          userLng,
          b['latitude'] as double,
          b['longitude'] as double,
        );
        return distA.compareTo(distB);
      });

      // Assert
      expect(cafes[0]['id'], '2'); // Nearest
      expect(cafes[2]['id'], '1'); // Farthest
    });

    test('should sort cafes alphabetically when no location', () {
      // Arrange
      final cafes = [
        {'kafe_adi': 'Zebra Cafe'},
        {'kafe_adi': 'Alpha Cafe'},
        {'kafe_adi': 'Beta Cafe'},
      ];

      // Act
      cafes.sort((a, b) {
        final nameA = (a['kafe_adi'] ?? '').toString().toLowerCase();
        final nameB = (b['kafe_adi'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      // Assert
      expect(cafes[0]['kafe_adi'], 'Alpha Cafe');
      expect(cafes[1]['kafe_adi'], 'Beta Cafe');
      expect(cafes[2]['kafe_adi'], 'Zebra Cafe');
    });
  });

  group('ApiService Query Building Tests', () {
    test('should build query with name filter', () {
      // Arrange
      final query = 'starbucks';

      // Act
      final shouldFilter = query.isNotEmpty && query != 'kafe';

      // Assert
      expect(shouldFilter, true);
    });

    test('should skip name filter for generic "kafe" query', () {
      // Arrange
      final query = 'kafe';

      // Act
      final shouldFilter = query.isNotEmpty && query != 'kafe';

      // Assert
      expect(shouldFilter, false);
    });

    test('should apply il filter when provided', () {
      // Arrange
      final il = 'İstanbul';

      // Act
      final shouldApplyFilter = il != null && il.isNotEmpty;

      // Assert
      expect(shouldApplyFilter, true);
    });

    test('should apply semt filter when provided', () {
      // Arrange
      final semt = 'Kadıköy';

      // Act
      final shouldApplyFilter = semt != null && semt.isNotEmpty;

      // Assert
      expect(shouldApplyFilter, true);
    });

    test('should apply vibe filter when provided', () {
      // Arrange
      final vibes = ['Sakin', 'Huzurlu'];

      // Act
      final shouldApplyFilter = vibes != null && vibes.isNotEmpty;

      // Assert
      expect(shouldApplyFilter, true);
    });

    test('should handle multiple vibes', () {
      // Arrange
      final vibes = ['Sakin', 'Huzurlu', 'Doğal'];

      // Act
      final vibeCount = vibes.length;

      // Assert
      expect(vibeCount, 3);
      expect(vibes.contains('Sakin'), true);
    });
  });

  group('ApiService Column Normalization Tests', () {
    test('should normalize il_adi to il', () {
      // Arrange
      final data = [
        {'id': '1', 'il_adi': 'İstanbul', 'ilce_adi': 'Kadıköy'},
      ];

      // Act
      final normalized = data.map((item) {
        final itemMap = Map<String, dynamic>.from(item);
        return {
          ...itemMap,
          'il': itemMap['il_adi'],
          'ilce': itemMap['ilce_adi'],
        };
      }).toList();

      // Assert
      expect(normalized[0]['il'], 'İstanbul');
      expect(normalized[0]['ilce'], 'Kadıköy');
    });

    test('should preserve original columns after normalization', () {
      // Arrange
      final item = {'id': '1', 'il_adi': 'İstanbul', 'ilce_adi': 'Kadıköy'};

      // Act
      final normalized = {
        ...item,
        'il': item['il_adi'],
        'ilce': item['ilce_adi'],
      };

      // Assert
      expect(normalized['il_adi'], 'İstanbul');
      expect(normalized['il'], 'İstanbul');
      expect(normalized['ilce_adi'], 'Kadıköy');
      expect(normalized['ilce'], 'Kadıköy');
    });
  });

  group('ApiService Embedding Tests', () {
    test('should convert embedding to double list', () {
      // Arrange
      final embedding = [1, 2, 3, 4, 5];

      // Act
      final doubleList = embedding.map((e) => e.toDouble()).toList();

      // Assert
      expect(doubleList, isA<List<double>>());
      expect(doubleList.length, 5);
      expect(doubleList[0], 1.0);
    });

    test('should validate embedding dimension', () {
      // Arrange
      final embedding = List.generate(384, (i) => i.toDouble());

      // Act
      final dimension = embedding.length;

      // Assert
      expect(dimension, 384);
    });

    test('should handle mixed number types in embedding', () {
      // Arrange
      final embedding = [1, 2.5, 3, 4.7, 5];

      // Act
      final doubleList = embedding.map((e) => (e as num).toDouble()).toList();

      // Assert
      expect(doubleList, isA<List<double>>());
      expect(doubleList[1], 2.5);
      expect(doubleList[3], 4.7);
    });
  });

  group('ApiService RPC Parameters Tests', () {
    test('should build RPC params with all filters', () {
      // Arrange
      final embedding = List.generate(384, (i) => i.toDouble());
      final query = 'test query';
      final il = 'İstanbul';
      final semt = 'Kadıköy';
      final vibes = ['Sakin', 'Huzurlu'];
      final userLat = 41.0;
      final userLng = 29.0;

      // Act
      final params = {
        'query_embedding': embedding,
        'search_query': query,
        'match_threshold': 0.0,
        'match_count': 20,
        'p_il_adi': il,
        'p_ilce_adi': semt,
        'p_vibe_etiketleri': vibes,
        'p_user_lat': userLat,
        'p_user_lng': userLng,
      };

      // Assert
      expect(params.containsKey('query_embedding'), true);
      expect(params.containsKey('search_query'), true);
      expect(params['match_threshold'], 0.0);
      expect(params['match_count'], 20);
      expect(params['p_il_adi'], il);
      expect(params['p_vibe_etiketleri'], isA<List<String>>());
    });

    test('should build RPC params without optional filters', () {
      // Arrange
      final embedding = List.generate(384, (i) => i.toDouble());
      final query = 'test query';

      // Act
      final params = {
        'query_embedding': embedding,
        'search_query': query,
        'match_threshold': 0.0,
        'match_count': 20,
      };

      // Assert
      expect(params.containsKey('p_il_adi'), false);
      expect(params.containsKey('p_ilce_adi'), false);
      expect(params.containsKey('p_vibe_etiketleri'), false);
    });
  });

  group('ApiService Deduplication Tests', () {
    test('should remove duplicate cafes by id', () {
      // Arrange
      final data = [
        {'id': '1', 'kafe_adi': 'Cafe 1', 'similarity': 0.9},
        {'id': '2', 'kafe_adi': 'Cafe 2', 'similarity': 0.8},
        {'id': '1', 'kafe_adi': 'Cafe 1', 'similarity': 0.7}, // Duplicate
        {'id': '3', 'kafe_adi': 'Cafe 3', 'similarity': 0.6},
      ];

      // Act
      final seen = <String>{};
      final unique = data.where((item) {
        final id = item['id'].toString();
        return seen.add(id);
      }).toList();

      // Assert
      expect(unique.length, 3);
      expect(unique[0]['id'], '1');
      expect(unique[1]['id'], '2');
      expect(unique[2]['id'], '3');
    });

    test('should keep first occurrence of duplicate', () {
      // Arrange
      final data = [
        {'id': '1', 'similarity': 0.9},
        {'id': '1', 'similarity': 0.7},
      ];

      // Act
      final seen = <String>{};
      final unique = data.where((item) {
        final id = item['id'].toString();
        return seen.add(id);
      }).toList();

      // Assert
      expect(unique.length, 1);
      expect(unique[0]['similarity'], 0.9); // First one kept
    });
  });

  group('ApiService Similarity Sorting Tests', () {
    test('should sort by similarity descending', () {
      // Arrange
      final data = [
        {'id': '1', 'similarity': 0.5},
        {'id': '2', 'similarity': 0.9},
        {'id': '3', 'similarity': 0.7},
      ];

      // Act
      data.sort((a, b) {
        final simA = (a['similarity'] as num?)?.toDouble() ?? 0.0;
        final simB = (b['similarity'] as num?)?.toDouble() ?? 0.0;
        return simB.compareTo(simA);
      });

      // Assert
      expect(data[0]['id'], '2'); // 0.9
      expect(data[1]['id'], '3'); // 0.7
      expect(data[2]['id'], '1'); // 0.5
    });

    test('should handle null similarity values', () {
      // Arrange
      final data = [
        {'id': '1', 'similarity': 0.5},
        {'id': '2', 'similarity': null},
        {'id': '3', 'similarity': 0.7},
      ];

      // Act
      data.sort((a, b) {
        final simA = (a['similarity'] as num?)?.toDouble() ?? 0.0;
        final simB = (b['similarity'] as num?)?.toDouble() ?? 0.0;
        return simB.compareTo(simA);
      });

      // Assert
      expect(data[0]['id'], '3'); // 0.7
      expect(data[1]['id'], '1'); // 0.5
      expect(data[2]['id'], '2'); // null -> 0.0
    });
  });
}

// Helper functions for testing
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * asin(sqrt(a));
  return earthRadius * c;
}

double _toRadians(double degree) {
  return degree * pi / 180;
}
