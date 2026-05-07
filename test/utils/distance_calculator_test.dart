import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

/// Haversine formula implementation for testing
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

void main() {
  group('Distance Calculator Tests (Haversine Formula)', () {
    test('should calculate distance between Istanbul and Ankara correctly', () {
      // Arrange - Istanbul to Ankara (approx 350km)
      final lat1 = 41.0082;
      final lon1 = 28.9784;
      final lat2 = 39.9334;
      final lon2 = 32.8597;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 350km
      expect(distance, greaterThan(300));
      expect(distance, lessThan(400));
      expect(distance, closeTo(350, 50));
    });

    test('should return 0 for same location', () {
      // Arrange
      final lat = 41.0082;
      final lon = 28.9784;

      // Act
      final distance = calculateDistance(lat, lon, lat, lon);

      // Assert
      expect(distance, 0.0);
    });

    test('should calculate distance between Istanbul and Izmir correctly', () {
      // Arrange - Istanbul to Izmir (approx 330km)
      final lat1 = 41.0082;
      final lon1 = 28.9784;
      final lat2 = 38.4237;
      final lon2 = 27.1428;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 330km
      expect(distance, greaterThan(280));
      expect(distance, lessThan(380));
    });

    test('should calculate distance between Istanbul and Antalya correctly', () {
      // Arrange - Istanbul to Antalya (approx 480km)
      final lat1 = 41.0082;
      final lon1 = 28.9784;
      final lat2 = 36.8969;
      final lon2 = 30.7133;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 480km
      expect(distance, greaterThan(430));
      expect(distance, lessThan(530));
    });

    test('should handle negative coordinates (Southern Hemisphere)', () {
      // Arrange - Sydney to Melbourne (approx 715km)
      final lat1 = -33.8688;
      final lon1 = 151.2093;
      final lat2 = -37.8136;
      final lon2 = 144.9631;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 715km
      expect(distance, greaterThan(650));
      expect(distance, lessThan(780));
    });

    test('should handle coordinates across prime meridian', () {
      // Arrange - London to Paris (approx 340km)
      final lat1 = 51.5074;
      final lon1 = -0.1278;
      final lat2 = 48.8566;
      final lon2 = 2.3522;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 340km
      expect(distance, greaterThan(300));
      expect(distance, lessThan(380));
    });

    test('should handle very small distances (within same city)', () {
      // Arrange - Two points in Istanbul (Taksim to Kadıköy, approx 10km)
      final lat1 = 41.0369;
      final lon1 = 28.9850;
      final lat2 = 40.9903;
      final lon2 = 29.0244;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 10km
      expect(distance, greaterThan(5));
      expect(distance, lessThan(15));
    });

    test('should handle very large distances (intercontinental)', () {
      // Arrange - Istanbul to New York (approx 8000km)
      final lat1 = 41.0082;
      final lon1 = 28.9784;
      final lat2 = 40.7128;
      final lon2 = -74.0060;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 8000km
      expect(distance, greaterThan(7500));
      expect(distance, lessThan(8500));
    });

    test('should handle equator coordinates', () {
      // Arrange - Two points on equator
      final lat1 = 0.0;
      final lon1 = 0.0;
      final lat2 = 0.0;
      final lon2 = 10.0;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 1113km (10 degrees at equator)
      expect(distance, greaterThan(1000));
      expect(distance, lessThan(1200));
    });

    test('should handle pole coordinates', () {
      // Arrange - North Pole to a point near it
      final lat1 = 90.0;
      final lon1 = 0.0;
      final lat2 = 89.0;
      final lon2 = 0.0;

      // Act
      final distance = calculateDistance(lat1, lon1, lat2, lon2);

      // Assert - Should be approximately 111km (1 degree of latitude)
      expect(distance, greaterThan(100));
      expect(distance, lessThan(120));
    });
  });

  group('Radians Conversion Tests', () {
    test('should convert 0 degrees to 0 radians', () {
      // Act
      final radians = _toRadians(0);

      // Assert
      expect(radians, 0.0);
    });

    test('should convert 90 degrees to pi/2 radians', () {
      // Act
      final radians = _toRadians(90);

      // Assert
      expect(radians, closeTo(pi / 2, 0.0001));
    });

    test('should convert 180 degrees to pi radians', () {
      // Act
      final radians = _toRadians(180);

      // Assert
      expect(radians, closeTo(pi, 0.0001));
    });

    test('should convert 360 degrees to 2*pi radians', () {
      // Act
      final radians = _toRadians(360);

      // Assert
      expect(radians, closeTo(2 * pi, 0.0001));
    });

    test('should handle negative degrees', () {
      // Act
      final radians = _toRadians(-90);

      // Assert
      expect(radians, closeTo(-pi / 2, 0.0001));
    });
  });
}
