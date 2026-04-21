import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // İlçe Listesini Çeker (Fallback Dummy Data ile)
  Future<List<String>> fetchIlceler() async {
    try {
      final response = await _client
          .from('ilce_isimli_kafeler')
          .select('ilce_adi')
          .timeout(const Duration(seconds: 5));

      if (response.isEmpty) return _dummyIlceler;
      return (response as List).map((e) => e['ilce_adi'].toString()).toList();
    } catch (e) {
      print("İlçe yükleme hatası: $e - Dummy data kullanılıyor");
      return _dummyIlceler;
    }
  }

  // Dinamik Vibe Etiketlerini Çeker (Fallback Dummy Data ile)
  Future<List<String>> fetchVibeEtiketleri() async {
    try {
      final response = await _client
          .from('dinamik_vibe_etiketleri')
          .select('etiket_adi')
          .timeout(const Duration(seconds: 5));

      if (response.isEmpty) return _dummyVibes;
      return (response as List).map((e) => e['etiket_adi'].toString()).toList();
    } catch (e) {
      print("Vibe yükleme hatası: $e - Dummy data kullanılıyor");
      return _dummyVibes;
    }
  }

  // Dinamik Semt Listesini Çeker
  Future<List<String>> fetchSemtler() async {
    final response = await _client.from('dinamik_semtler').select();

    return (response as List).map((e) => e['semt_adi'].toString()).toList();
  }

  // Şehre göre ilçeleri çeker
  Future<List<String>> fetchIlcelerByIl(String il) async {
    try {
      final response = await _client
          .from('kafeler')
          .select('ilce')
          .eq('il', il)
          .not('ilce', 'is', null)
          .timeout(const Duration(seconds: 5));

      if (response.isEmpty) return _ilcelerByIl[il] ?? [];
      final ilceler = (response as List)
          .map((e) => e['ilce'].toString())
          .toSet()
          .toList()
        ..sort();
      return ilceler;
    } catch (e) {
      return _ilcelerByIl[il] ?? [];
    }
  }

  // Fallback: şehre göre dummy ilçeler
  static const Map<String, List<String>> _ilcelerByIl = {
    'İstanbul': [
      'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar',
      'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş',
      'Beykoz', 'Beylikdüzü', 'Beyoğlu', 'Büyükçekmece', 'Çatalca',
      'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih',
      'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal',
      'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
      'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli',
      'Tuzla', 'Ümraniye', 'Üsküdar', 'Zeytinburnu',
    ],
    'Ankara': [
      'Altındağ', 'Çankaya', 'Etimesgut', 'Gölbaşı', 'Keçiören',
      'Kızılcahamam', 'Mamak', 'Pursaklar', 'Sincan', 'Yenimahalle',
    ],
    'İzmir': [
      'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama',
      'Bornova', 'Buca', 'Çiğli', 'Gaziemir', 'Güzelbahçe',
      'Karabağlar', 'Karşıyaka', 'Kemalpaşa', 'Konak', 'Menderes',
      'Narlıdere', 'Torbalı', 'Urla',
    ],
  };

  // Dummy İlçeler
  static const List<String> _dummyIlceler = [
    'Beyoğlu',
    'Fatih',
    'Kadıköy',
    'Beşiktaş',
    'Şişli',
    'Arnavutköy',
    'Çankırı',
    'Maltepe',
  ];

  // Dummy Vibe Etiketleri
  static const List<String> _dummyVibes = [
    'Sakin',
    'Enerjik',
    'Romantik',
    'Sosyal',
    'Çalışmaya Uygun',
    'Live Müzik',
    'Kahvesi İyi',
    'Eğlenceli',
  ];

  Future<void> sendCollectionToFriend({
    required String friendId,
    required String collectionId,
  }) async {
    final myId = _client.auth.currentUser!.id;

    // 1. Bu arkadaşla arandaki chat_id'yi bul (veya oluştur)
    // Not: 'chats' tablonun yapısına göre burayı düzenlemelisin.
    // Genelde iki kullanıcının ID'sini içeren odayı sorgularız.
    final chatResponse = await _client
        .from('chats')
        .select('id')
        .or(
          'and(user1_id.eq.$myId,user2_id.eq.$friendId),and(user1_id.eq.$friendId,user2_id.eq.$myId)',
        )
        .maybeSingle();

    String chatId;

    if (chatResponse == null) {
      // Sohbet yoksa yeni bir tane oluştur
      final newChat = await _client
          .from('chats')
          .insert({'user1_id': myId, 'user2_id': friendId})
          .select()
          .single();
      chatId = newChat['id'];
    } else {
      chatId = chatResponse['id'];
    }

    // 2. Mesajı gönder
    await _client.from('messages').insert({
      'chat_id': chatId, // Senin sütun ismin
      'sender_id': myId, // Senin sütun ismin
      'collection_id': collectionId, // Senin sütun ismin
      'content': 'Sana bir koleksiyon gönderdi!', // Senin sütun ismin
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
