import 'package:flutter_test/flutter_test.dart';
import 'package:ugrak_mekan_app/models/cafe_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('Cafe Model Tests', () {
    test('Cafe.fromJson should parse valid JSON correctly', () {
      // Arrange
      final json = {
        'id': '123',
        'kafe_adi': 'Test Cafe',
        'user_id': 'user123',
        'ilce_adi': 'Kadıköy',
        'semt_adi': 'Moda',
        'vibe_etiketleri': ['Sakin', 'Romantik'],
        'latitude': 41.0082,
        'longitude': 28.9784,
        'similarity': 0.85,
        'cafe_gorselleri': [
          {'foto_url': 'https://example.com/photo1.jpg', 'kaynak_tipi': 'official', 'oncelik_sirasi': 1}
        ],
        'yorumlar': [
          {'id': 'y1', 'yorum_metni': 'Harika bir yer'}
        ],
        'cafe_postlar': [
          {'id': 'p1', 'baslik': 'Güzel mekan'}
        ],
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.id, '123');
      expect(cafe.kafeAdi, 'Test Cafe');
      expect(cafe.userId, 'user123');
      expect(cafe.ilceAdi, 'Kadıköy');
      expect(cafe.semtAdi, 'Moda');
      expect(cafe.vibeEtiketleri, ['Sakin', 'Romantik']);
      expect(cafe.latitude, 41.0082);
      expect(cafe.longitude, 28.9784);
      expect(cafe.similarity, 0.85);
      expect(cafe.gorseller.length, 1);
      expect(cafe.yorumlar.length, 1);
      expect(cafe.postlar.length, 1);
    });

    test('Cafe.fromJson should handle missing optional fields', () {
      // Arrange
      final json = {
        'id': '456',
        'kafe_adi': 'Minimal Cafe',
        'latitude': 39.9334,
        'longitude': 32.8597,
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.id, '456');
      expect(cafe.kafeAdi, 'Minimal Cafe');
      expect(cafe.userId, null);
      expect(cafe.ilceAdi, 'İlçe Belirtilmemiş');
      expect(cafe.semtAdi, 'Semt Belirtilmemiş');
      expect(cafe.vibeEtiketleri, isEmpty);
      expect(cafe.similarity, 0.0);
      expect(cafe.gorseller, isEmpty);
      expect(cafe.yorumlar, isEmpty);
      expect(cafe.postlar, isEmpty);
    });

    test('Cafe.fromJson should handle legacy fotograflar field', () {
      // Arrange
      final json = {
        'id': '789',
        'kafe_adi': 'Legacy Cafe',
        'latitude': 40.0,
        'longitude': 29.0,
        'fotograflar': ['https://example.com/old1.jpg', 'https://example.com/old2.jpg'],
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.gorseller.length, 2);
      expect(cafe.gorseller[0]['foto_url'], 'https://example.com/old1.jpg');
      expect(cafe.gorseller[0]['kaynak_tipi'], 'official');
      expect(cafe.gorseller[1]['foto_url'], 'https://example.com/old2.jpg');
    });

    test('Cafe.fromJson should handle ilce field fallback', () {
      // Arrange
      final json = {
        'id': '999',
        'kafe_adi': 'Fallback Cafe',
        'ilce': 'Beşiktaş',
        'latitude': 41.0,
        'longitude': 29.0,
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.ilceAdi, 'Beşiktaş');
    });

    test('Cafe.location should return correct LatLng', () {
      // Arrange
      final json = {
        'id': '111',
        'kafe_adi': 'Location Test',
        'latitude': 41.0082,
        'longitude': 28.9784,
      };
      final cafe = Cafe.fromJson(json);

      // Act
      final location = cafe.location;

      // Assert
      expect(location, isA<LatLng>());
      expect(location.latitude, 41.0082);
      expect(location.longitude, 28.9784);
    });

    test('Cafe.toJson should serialize correctly', () {
      // Arrange
      final cafe = Cafe(
        id: '222',
        kafeAdi: 'Serialize Test',
        userId: 'user222',
        vibeEtiketleri: ['Enerjik'],
        ilceAdi: 'Şişli',
        semtAdi: 'Nişantaşı',
        latitude: 41.05,
        longitude: 28.99,
        similarity: 0.75,
        gorseller: [
          {'foto_url': 'test.jpg', 'kaynak_tipi': 'user'}
        ],
        yorumlar: [],
        postlar: [],
      );

      // Act
      final json = cafe.toJson();

      // Assert
      expect(json['id'], '222');
      expect(json['kafe_adi'], 'Serialize Test');
      expect(json['user_id'], 'user222');
      expect(json['vibe_etiketleri'], ['Enerjik']);
      expect(json['ilce_adi'], 'Şişli');
      expect(json['semt_adi'], 'Nişantaşı');
      expect(json['latitude'], 41.05);
      expect(json['longitude'], 28.99);
      expect(json['similarity'], 0.75);
      expect(json['cafe_gorselleri'], isA<List>());
    });

    test('Cafe.fromJson should handle null cafe_postlar and use postlar fallback', () {
      // Arrange
      final json = {
        'id': '333',
        'kafe_adi': 'Postlar Test',
        'latitude': 40.0,
        'longitude': 29.0,
        'postlar': [
          {'id': 'p1', 'baslik': 'Test Post'}
        ],
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.postlar.length, 1);
      expect(cafe.postlar[0]['id'], 'p1');
    });

    test('Cafe.fromJson should handle empty strings as default values', () {
      // Arrange
      final json = {
        'id': '',
        'kafe_adi': '',
        'latitude': 0.0,
        'longitude': 0.0,
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.id, '');
      expect(cafe.kafeAdi, ''); // Empty string is kept as is
      expect(cafe.latitude, 0.0);
      expect(cafe.longitude, 0.0);
    });

    test('Cafe.fromJson should handle numeric id conversion', () {
      // Arrange
      final json = {
        'id': 12345,
        'kafe_adi': 'Numeric ID Test',
        'latitude': 40.0,
        'longitude': 29.0,
      };

      // Act
      final cafe = Cafe.fromJson(json);

      // Assert
      expect(cafe.id, '12345');
    });
  });
}
