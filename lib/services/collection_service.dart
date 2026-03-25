import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionService {
  final _supabase = Supabase.instance.client;

  Future<List<dynamic>> fetchUserCollections(String userId) async {
    return await _supabase
        .from('koleksiyonlar')
        .select()
        .eq('user_id', userId)
        .order('isim');
  }

  Future<void> createCollection(String name) async {
    await _supabase.from('koleksiyonlar').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'isim': name,
      'is_public': true,
    });
  }

  Future<void> deleteCollection(String id) async {
    await _supabase.from('koleksiyonlar').delete().eq('id', id);
  }

  Future<void> updatePrivacy(String id, bool currentStatus) async {
    await _supabase
        .from('koleksiyonlar')
        .update({'is_public': !currentStatus})
        .eq('id', id);
  }

  Future<void> sendToFriend(
    String targetUserId,
    String colId,
    String colName,
  ) async {
    await _supabase.from('messages').insert({
      'sender_id': _supabase.auth.currentUser!.id,
      'receiver_id': targetUserId,
      'content':
          'Sana bir koleksiyon gönderdi: $colName\nhttps://haticeeakgull.github.io/?koleksiyonId=$colId',
      'is_collection': true,
      'collection_id': colId,
    });
  }
}
