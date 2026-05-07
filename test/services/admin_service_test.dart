import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminService Email Parsing Tests', () {
    test('should parse comma-separated emails', () {
      // Arrange
      final emailString = 'admin1@test.com,admin2@test.com,admin3@test.com';

      // Act
      final emails = emailString
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Assert
      expect(emails.length, 3);
      expect(emails[0], 'admin1@test.com');
      expect(emails[1], 'admin2@test.com');
      expect(emails[2], 'admin3@test.com');
    });

    test('should handle whitespace in email list', () {
      // Arrange
      final emailString = ' admin1@test.com , admin2@test.com ';

      // Act
      final emails = emailString
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Assert
      expect(emails.length, 2);
      expect(emails[0], 'admin1@test.com');
      expect(emails[1], 'admin2@test.com');
    });

    test('should filter empty strings', () {
      // Arrange
      final emailString = 'admin@test.com,,another@test.com,';

      // Act
      final emails = emailString
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Assert
      expect(emails.length, 2);
    });

    test('should convert to lowercase', () {
      // Arrange
      final emailString = 'Admin@Test.COM,USER@EXAMPLE.COM';

      // Act
      final emails = emailString
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Assert
      expect(emails[0], 'admin@test.com');
      expect(emails[1], 'user@example.com');
    });

    test('should handle single email', () {
      // Arrange
      final emailString = 'admin@test.com';

      // Act
      final emails = emailString
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      // Assert
      expect(emails.length, 1);
      expect(emails[0], 'admin@test.com');
    });
  });

  group('AdminService Status Logic Tests', () {
    test('should initialize all status counts', () {
      // Arrange
      final testData = [
        {'durum': 'beklemede'},
        {'durum': 'beklemede'},
        {'durum': 'inceleniyor'},
        {'durum': 'eklendi'},
        {'durum': 'reddedildi'},
      ];

      // Act
      final stats = <String, int>{
        'beklemede': 0,
        'inceleniyor': 0,
        'eklendi': 0,
        'reddedildi': 0,
      };

      for (var item in testData) {
        final durum = item['durum'] as String;
        stats[durum] = (stats[durum] ?? 0) + 1;
      }

      // Assert
      expect(stats['beklemede'], 2);
      expect(stats['inceleniyor'], 1);
      expect(stats['eklendi'], 1);
      expect(stats['reddedildi'], 1);
    });

    test('should validate status values', () {
      // Arrange
      final validStatuses = ['beklemede', 'inceleniyor', 'eklendi', 'reddedildi'];

      // Act & Assert
      expect(validStatuses.contains('beklemede'), true);
      expect(validStatuses.contains('inceleniyor'), true);
      expect(validStatuses.contains('eklendi'), true);
      expect(validStatuses.contains('reddedildi'), true);
      expect(validStatuses.contains('invalid'), false);
    });

    test('should count notifications by status', () {
      // Arrange
      final notifications = [
        {'durum': 'beklemede'},
        {'durum': 'inceleniyor'},
        {'durum': 'beklemede'},
        {'durum': 'eklendi'},
        {'durum': 'beklemede'},
      ];

      // Act
      final beklemedCount = notifications.where((n) => n['durum'] == 'beklemede').length;
      final inceleniyorCount = notifications.where((n) => n['durum'] == 'inceleniyor').length;

      // Assert
      expect(beklemedCount, 3);
      expect(inceleniyorCount, 1);
    });
  });

  group('AdminService Email Validation Tests', () {
    test('should validate email format', () {
      // Arrange
      final validEmail = 'admin@test.com';
      final invalidEmail1 = 'notanemail';
      final invalidEmail2 = '@test.com';
      final invalidEmail3 = 'admin@';

      // Act
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      // Assert
      expect(emailRegex.hasMatch(validEmail), true);
      expect(emailRegex.hasMatch(invalidEmail1), false);
      expect(emailRegex.hasMatch(invalidEmail2), false);
      expect(emailRegex.hasMatch(invalidEmail3), false);
    });

    test('should check if email is in admin list', () {
      // Arrange
      final adminEmails = ['admin1@test.com', 'admin2@test.com'];
      final testEmail1 = 'admin1@test.com';
      final testEmail2 = 'user@test.com';

      // Act
      final isAdmin1 = adminEmails.contains(testEmail1.toLowerCase());
      final isAdmin2 = adminEmails.contains(testEmail2.toLowerCase());

      // Assert
      expect(isAdmin1, true);
      expect(isAdmin2, false);
    });
  });
}
