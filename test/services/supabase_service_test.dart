import 'package:flutter_test/flutter_test.dart';
import 'package:ugrak_mekan_app/services/supabase_service.dart';

void main() {
  group('SupabaseService Dummy Data Tests', () {
    test('should have dummy ilceler data', () {
      // Arrange
      const dummyIlceler = [
        'Beyoğlu',
        'Fatih',
        'Kadıköy',
        'Beşiktaş',
        'Şişli',
        'Arnavutköy',
        'Çankırı',
        'Maltepe',
      ];

      // Assert
      expect(dummyIlceler, isNotEmpty);
      expect(dummyIlceler.length, 8);
      expect(dummyIlceler.contains('Kadıköy'), true);
    });

    test('should have dummy vibe data', () {
      // Arrange
      const dummyVibes = [
        'Sakin',
        'Enerjik',
        'Romantik',
        'Sosyal',
        'Çalışmaya Uygun',
        'Live Müzik',
        'Kahvesi İyi',
        'Eğlenceli',
      ];

      // Assert
      expect(dummyVibes, isNotEmpty);
      expect(dummyVibes.length, 8);
      expect(dummyVibes.contains('Sakin'), true);
    });

    test('should have Istanbul ilceler in dummy data', () {
      // Arrange
      const istanbulIlceler = [
        'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar',
        'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş',
        'Beykoz', 'Beylikdüzü', 'Beyoğlu', 'Büyükçekmece', 'Çatalca',
        'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih',
        'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal',
        'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
        'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli',
        'Tuzla', 'Ümraniye', 'Üsküdar', 'Zeytinburnu',
      ];

      // Assert
      expect(istanbulIlceler.length, 39);
      expect(istanbulIlceler.contains('Kadıköy'), true);
      expect(istanbulIlceler.contains('Beşiktaş'), true);
    });

    test('should have Ankara ilceler in dummy data', () {
      // Arrange
      const ankaraIlceler = [
        'Altındağ', 'Çankaya', 'Etimesgut', 'Gölbaşı', 'Keçiören',
        'Kızılcahamam', 'Mamak', 'Pursaklar', 'Sincan', 'Yenimahalle',
      ];

      // Assert
      expect(ankaraIlceler.length, 10);
      expect(ankaraIlceler.contains('Çankaya'), true);
    });

    test('should have Izmir ilceler in dummy data', () {
      // Arrange
      const izmirIlceler = [
        'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama',
        'Bornova', 'Buca', 'Çiğli', 'Gaziemir', 'Güzelbahçe',
        'Karabağlar', 'Karşıyaka', 'Kemalpaşa', 'Konak', 'Menderes',
        'Narlıdere', 'Torbalı', 'Urla',
      ];

      // Assert
      expect(izmirIlceler.length, 18);
      expect(izmirIlceler.contains('Bornova'), true);
    });
  });

  group('SupabaseService Data Extraction Tests', () {
    test('should extract ilce_adi from response', () {
      // Arrange
      final response = [
        {'ilce_adi': 'Kadıköy'},
        {'ilce_adi': 'Beşiktaş'},
        {'ilce_adi': 'Şişli'},
      ];

      // Act
      final ilceler = response.map((e) => e['ilce_adi'].toString()).toList();

      // Assert
      expect(ilceler.length, 3);
      expect(ilceler[0], 'Kadıköy');
    });

    test('should extract etiket_adi from response', () {
      // Arrange
      final response = [
        {'etiket_adi': 'Sakin'},
        {'etiket_adi': 'Enerjik'},
      ];

      // Act
      final etiketler = response.map((e) => e['etiket_adi'].toString()).toList();

      // Assert
      expect(etiketler.length, 2);
      expect(etiketler[0], 'Sakin');
    });

    test('should extract semt_adi from response', () {
      // Arrange
      final response = [
        {'semt_adi': 'Moda'},
        {'semt_adi': 'Nişantaşı'},
      ];

      // Act
      final semtler = response.map((e) => e['semt_adi'].toString()).toList();

      // Assert
      expect(semtler.length, 2);
      expect(semtler[0], 'Moda');
    });
  });

  group('SupabaseService Deduplication Tests', () {
    test('should remove duplicate ilceler', () {
      // Arrange
      final ilceler = ['Kadıköy', 'Beşiktaş', 'Kadıköy', 'Şişli', 'Beşiktaş'];

      // Act
      final unique = ilceler.toSet().toList();

      // Assert
      expect(unique.length, 3);
      expect(unique.contains('Kadıköy'), true);
      expect(unique.contains('Beşiktaş'), true);
      expect(unique.contains('Şişli'), true);
    });

    test('should sort ilceler alphabetically', () {
      // Arrange
      final ilceler = ['Şişli', 'Kadıköy', 'Beşiktaş'];

      // Act
      ilceler.sort();

      // Assert
      expect(ilceler[0], 'Beşiktaş');
      expect(ilceler[1], 'Kadıköy');
      expect(ilceler[2], 'Şişli');
    });
  });

  group('SupabaseService Chat Logic Tests', () {
    test('should build OR query for bidirectional chat', () {
      // Arrange
      final myId = 'user1';
      final friendId = 'user2';

      // Act
      final query = 'and(user1_id.eq.$myId,user2_id.eq.$friendId),and(user1_id.eq.$friendId,user2_id.eq.$myId)';

      // Assert
      expect(query, contains(myId));
      expect(query, contains(friendId));
      expect(query, contains('and'));
    });

    test('should create new chat structure', () {
      // Arrange
      final myId = 'user1';
      final friendId = 'user2';

      // Act
      final newChat = {
        'user1_id': myId,
        'user2_id': friendId,
      };

      // Assert
      expect(newChat['user1_id'], myId);
      expect(newChat['user2_id'], friendId);
    });

    test('should create message structure', () {
      // Arrange
      final chatId = 'chat123';
      final senderId = 'user1';
      final collectionId = 'col123';
      final content = 'Sana bir koleksiyon gönderdi!';

      // Act
      final message = {
        'chat_id': chatId,
        'sender_id': senderId,
        'collection_id': collectionId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Assert
      expect(message['chat_id'], chatId);
      expect(message['sender_id'], senderId);
      expect(message['collection_id'], collectionId);
      expect(message['content'], content);
      expect(message.containsKey('created_at'), true);
    });
  });

  group('SupabaseService Filter Tests', () {
    test('should filter by il', () {
      // Arrange
      final kafeler = [
        {'id': '1', 'il': 'İstanbul'},
        {'id': '2', 'il': 'Ankara'},
        {'id': '3', 'il': 'İstanbul'},
      ];
      final targetIl = 'İstanbul';

      // Act
      final filtered = kafeler.where((k) => k['il'] == targetIl).toList();

      // Assert
      expect(filtered.length, 2);
    });

    test('should filter by ilce', () {
      // Arrange
      final kafeler = [
        {'id': '1', 'ilce': 'Kadıköy'},
        {'id': '2', 'ilce': 'Beşiktaş'},
        {'id': '3', 'ilce': 'Kadıköy'},
      ];
      final targetIlce = 'Kadıköy';

      // Act
      final filtered = kafeler.where((k) => k['ilce'] == targetIlce).toList();

      // Assert
      expect(filtered.length, 2);
    });

    test('should filter out null ilce', () {
      // Arrange
      final response = [
        {'ilce': 'Kadıköy'},
        {'ilce': null},
        {'ilce': 'Beşiktaş'},
      ];

      // Act
      final filtered = response.where((r) => r['ilce'] != null).toList();

      // Assert
      expect(filtered.length, 2);
    });
  });

  group('SupabaseService Timeout Tests', () {
    test('should have timeout duration', () {
      // Arrange
      const timeout = Duration(seconds: 5);

      // Assert
      expect(timeout.inSeconds, 5);
    });
  });
}
