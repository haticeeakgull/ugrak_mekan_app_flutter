import 'package:flutter_test/flutter_test.dart';

/// Time range checker implementation for testing
bool isTimeInRange(String time, String start, String end) {
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

void main() {
  group('Time Range Checker Tests', () {
    group('Normal Time Ranges (Same Day)', () {
      test('should return true for time within range', () {
        // Arrange
        final time = '14:30';
        final start = '09:00';
        final end = '17:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return false for time before range', () {
        // Arrange
        final time = '08:30';
        final start = '09:00';
        final end = '17:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });

      test('should return false for time after range', () {
        // Arrange
        final time = '18:00';
        final start = '09:00';
        final end = '17:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });

      test('should return true for time at start boundary', () {
        // Arrange
        final time = '09:00';
        final start = '09:00';
        final end = '17:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return true for time at end boundary', () {
        // Arrange
        final time = '17:00';
        final start = '09:00';
        final end = '17:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should handle lunch break range', () {
        // Arrange
        final time = '12:30';
        final start = '12:00';
        final end = '13:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should handle early morning range', () {
        // Arrange
        final time = '06:45';
        final start = '06:00';
        final end = '08:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });
    });

    group('Midnight Crossing Time Ranges', () {
      test('should return true for late night time (22:00-02:00)', () {
        // Arrange
        final time = '23:30';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return true for early morning time (22:00-02:00)', () {
        // Arrange
        final time = '01:30';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return true for time at midnight (22:00-02:00)', () {
        // Arrange
        final time = '00:00';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return false for time outside midnight range', () {
        // Arrange
        final time = '15:00';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });

      test('should return true for time at start of midnight range', () {
        // Arrange
        final time = '22:00';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return true for time at end of midnight range', () {
        // Arrange
        final time = '02:00';
        final start = '22:00';
        final end = '02:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should handle night owl range (23:00-04:00)', () {
        // Arrange
        final time = '03:15';
        final start = '23:00';
        final end = '04:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return false for afternoon in night range', () {
        // Arrange
        final time = '14:00';
        final start = '23:00';
        final end = '04:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });
    });

    group('Edge Cases', () {
      test('should handle single hour range', () {
        // Arrange
        final time = '12:30';
        final start = '12:00';
        final end = '13:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should handle full day range', () {
        // Arrange
        final time = '15:45';
        final start = '00:00';
        final end = '23:59';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should handle minutes precision', () {
        // Arrange
        final time = '09:15';
        final start = '09:10';
        final end = '09:20';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return false for time just before range', () {
        // Arrange
        final time = '09:09';
        final start = '09:10';
        final end = '09:20';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });

      test('should return false for time just after range', () {
        // Arrange
        final time = '09:21';
        final start = '09:10';
        final end = '09:20';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });

      test('should handle same start and end time', () {
        // Arrange
        final time = '12:00';
        final start = '12:00';
        final end = '12:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, true);
      });

      test('should return false for different time when start equals end', () {
        // Arrange
        final time = '12:01';
        final start = '12:00';
        final end = '12:00';

        // Act
        final result = isTimeInRange(time, start, end);

        // Assert
        expect(result, false);
      });
    });

    group('Real-World Scenarios', () {
      test('should validate cafe opening hours (08:00-22:00)', () {
        // Arrange
        final morningTime = '09:30';
        final afternoonTime = '15:00';
        final eveningTime = '21:30';
        final closedTime = '23:00';
        final start = '08:00';
        final end = '22:00';

        // Act & Assert
        expect(isTimeInRange(morningTime, start, end), true);
        expect(isTimeInRange(afternoonTime, start, end), true);
        expect(isTimeInRange(eveningTime, start, end), true);
        expect(isTimeInRange(closedTime, start, end), false);
      });

      test('should validate late night cafe hours (20:00-04:00)', () {
        // Arrange
        final eveningTime = '21:00';
        final midnightTime = '00:30';
        final earlyMorningTime = '03:00';
        final morningTime = '10:00';
        final start = '20:00';
        final end = '04:00';

        // Act & Assert
        expect(isTimeInRange(eveningTime, start, end), true);
        expect(isTimeInRange(midnightTime, start, end), true);
        expect(isTimeInRange(earlyMorningTime, start, end), true);
        expect(isTimeInRange(morningTime, start, end), false);
      });

      test('should validate breakfast hours (07:00-11:00)', () {
        // Arrange
        final breakfastTime = '09:00';
        final lunchTime = '12:00';
        final start = '07:00';
        final end = '11:00';

        // Act & Assert
        expect(isTimeInRange(breakfastTime, start, end), true);
        expect(isTimeInRange(lunchTime, start, end), false);
      });

      test('should validate happy hour (17:00-19:00)', () {
        // Arrange
        final happyHourTime = '18:00';
        final afterHappyHour = '20:00';
        final start = '17:00';
        final end = '19:00';

        // Act & Assert
        expect(isTimeInRange(happyHourTime, start, end), true);
        expect(isTimeInRange(afterHappyHour, start, end), false);
      });
    });
  });
}
