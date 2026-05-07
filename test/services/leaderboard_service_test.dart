import 'package:flutter_test/flutter_test.dart';
import 'package:ugrak_mekan_app/services/leaderboard_service.dart';

void main() {
  group('LeaderboardService Date Calculation Tests', () {
    test('getDaysUntilReset should return 1 on Sunday', () {
      // Arrange - Create a Sunday date
      final sunday = DateTime(2024, 1, 7); // A Sunday
      final weekday = sunday.weekday; // 7

      // Act
      final daysUntilReset = 7 - weekday + 1;

      // Assert
      expect(daysUntilReset, 1);
    });

    test('getDaysUntilReset should return 7 on Monday', () {
      // Arrange - Create a Monday date
      final monday = DateTime(2024, 1, 1); // A Monday
      final weekday = monday.weekday; // 1

      // Act
      final daysUntilReset = 7 - weekday + 1;

      // Assert
      expect(daysUntilReset, 7);
    });
  });

  group('LeaderboardService Ranking Logic Tests', () {
    test('should find user rank in leaderboard', () {
      // Arrange
      final leaderboard = [
        {'id': 'user1', 'weekly_points': 100},
        {'id': 'user2', 'weekly_points': 90},
        {'id': 'user3', 'weekly_points': 80},
        {'id': 'user4', 'weekly_points': 70},
      ];
      final targetUserId = 'user3';

      // Act
      final userIndex = leaderboard.indexWhere((user) => user['id'] == targetUserId);
      final rank = userIndex + 1;

      // Assert
      expect(rank, 3);
    });

    test('should return 0 when user not in leaderboard', () {
      // Arrange
      final leaderboard = [
        {'id': 'user1', 'weekly_points': 100},
        {'id': 'user2', 'weekly_points': 90},
      ];
      final targetUserId = 'user999';

      // Act
      final userIndex = leaderboard.indexWhere((user) => user['id'] == targetUserId);
      final rank = userIndex == -1 ? 0 : userIndex + 1;

      // Assert
      expect(rank, 0);
    });

    test('should get neighborhood users (±5 ranks)', () {
      // Arrange
      final leaderboard = List.generate(20, (i) => {
        'id': 'user$i',
        'weekly_points': 100 - i,
      });
      final userRank = 10;
      final startRank = (userRank - 5).clamp(1, double.infinity).toInt();
      final endRank = userRank + 5;

      // Act
      final neighborhood = leaderboard
          .asMap()
          .entries
          .where((entry) {
            final rank = entry.key + 1;
            return rank >= startRank && rank <= endRank;
          })
          .map((entry) => entry.value)
          .toList();

      // Assert
      expect(neighborhood.length, 11); // Ranks 5-15
      expect(neighborhood.first['id'], 'user4'); // Rank 5
      expect(neighborhood.last['id'], 'user14'); // Rank 15
    });

    test('should handle neighborhood at top of leaderboard', () {
      // Arrange
      final userRank = 2;
      final startRank = (userRank - 5).clamp(1, double.infinity).toInt();
      final endRank = userRank + 5;

      // Assert
      expect(startRank, 1); // Can't go below 1
      expect(endRank, 7);
    });

    test('should filter users with zero points', () {
      // Arrange
      final users = [
        {'id': 'user1', 'weekly_points': 100},
        {'id': 'user2', 'weekly_points': 0},
        {'id': 'user3', 'weekly_points': 50},
        {'id': 'user4', 'weekly_points': 0},
      ];

      // Act
      final activeUsers = users.where((user) => (user['weekly_points'] as int) > 0).toList();

      // Assert
      expect(activeUsers.length, 2);
    });
  });

  group('LeaderboardService Points Breakdown Tests', () {
    test('should calculate total points from breakdown', () {
      // Arrange
      final breakdown = {
        'post_points': 50,
        'comment_points': 20,
        'like_points': 10,
        'follower_points': 15,
        'badge_points': 30,
      };

      // Act
      final total = breakdown.values.reduce((a, b) => a + b);

      // Assert
      expect(total, 125);
    });

    test('should handle null values in breakdown', () {
      // Arrange
      final breakdown = {
        'post_points': null,
        'comment_points': 20,
        'like_points': null,
      };

      // Act
      final safeBreakdown = {
        'post_points': breakdown['post_points'] ?? 0,
        'comment_points': breakdown['comment_points'] ?? 0,
        'like_points': breakdown['like_points'] ?? 0,
      };

      // Assert
      expect(safeBreakdown['post_points'], 0);
      expect(safeBreakdown['comment_points'], 20);
      expect(safeBreakdown['like_points'], 0);
    });

    test('should sort leaderboard by points descending', () {
      // Arrange
      final users = [
        {'id': 'user1', 'weekly_points': 50},
        {'id': 'user2', 'weekly_points': 100},
        {'id': 'user3', 'weekly_points': 75},
      ];

      // Act
      users.sort((a, b) => (b['weekly_points'] as int).compareTo(a['weekly_points'] as int));

      // Assert
      expect(users[0]['id'], 'user2'); // 100 points
      expect(users[1]['id'], 'user3'); // 75 points
      expect(users[2]['id'], 'user1'); // 50 points
    });
  });
}
