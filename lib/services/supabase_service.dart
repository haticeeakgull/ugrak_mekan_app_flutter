import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // Dinamik Semt Listesini Çeker
  Future<List<String>> fetchSemtler() async {
    final response = await _client.from('dinamik_semtler').select();

    return (response as List).map((e) => e['semt_adi'].toString()).toList();
  }

  // Dinamik Vibe Etiketlerini Çeker
  Future<List<String>> fetchVibeEtiketleri() async {
    final response = await _client.from('dinamik_vibe_etiketleri').select();
    return (response as List).map((e) => e['etiket_adi'].toString()).toList();
  }

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
