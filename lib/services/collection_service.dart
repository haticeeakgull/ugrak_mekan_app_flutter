import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionService {
  final _supabase = Supabase.instance.client;

  Future<List<dynamic>> fetchUserCollections(String userId) async {
    try {
      // Koleksiyonları ve ilişkili verileri tek sorguda çek
      final collections = await _supabase
          .from('koleksiyonlar')
          .select('''
            *,
            koleksiyon_ogeleri (
              ilce_isimli_kafeler (
                id
              )
            )
          ''')
          .eq('user_id', userId)
          .order('isim');

      // Her koleksiyon için kafe fotolarını çek
      for (var col in collections) {
        List<String> photos = [];
        
        try {
          final items = col['koleksiyon_ogeleri'] as List?;
          
          if (items != null && items.isNotEmpty) {
            // İlk 4 kafe için foto çek
            for (var i = 0; i < items.length && i < 4; i++) {
              try {
                final cafe = items[i]['ilce_isimli_kafeler'];
                if (cafe != null && cafe['id'] != null) {
                  final cafeId = cafe['id'];
                  
                  // Önce cafe_postlar'dan Supabase Storage fotoları dene
                  final postFoto = await _supabase
                      .from('cafe_postlar')
                      .select('foto_url')
                      .eq('cafe_id', cafeId)
                      .not('foto_url', 'is', null)
                      .limit(1)
                      .maybeSingle();

                  if (postFoto != null && postFoto['foto_url'] != null) {
                    final fotoUrl = postFoto['foto_url'] as String;
                    // Sadece Supabase Storage URL'lerini al (Google Maps değil)
                    if (fotoUrl.contains('supabase') || 
                        fotoUrl.startsWith('http') && !fotoUrl.contains('googleapis')) {
                      photos.add(fotoUrl);
                      continue;
                    }
                  }

                  // Yoksa cafe_fotograflar'dan dene
                  final cafeList = await _supabase
                      .from('cafe_fotograflar')
                      .select('foto_url')
                      .eq('cafe_id', cafeId)
                      .limit(1);

                  if (cafeList.isNotEmpty && cafeList[0]['foto_url'] != null) {
                    final fotoUrl = cafeList[0]['foto_url'] as String;
                    // Sadece Supabase Storage URL'lerini al
                    if (fotoUrl.contains('supabase') || 
                        fotoUrl.startsWith('http') && !fotoUrl.contains('googleapis')) {
                      photos.add(fotoUrl);
                    }
                  }
                }
              } catch (e) {
                print('Kafe foto hatası: $e');
              }
            }
          }
        } catch (e) {
          print('Koleksiyon öğeleri hatası: $e');
        }

        col['cafe_photos'] = photos;
        if (photos.isNotEmpty) {
          col['first_cafe_photo'] = photos.first;
        }
        
        print('✅ Koleksiyon "${col['isim']}": ${photos.length} foto (Storage)');
      }

      return collections;
    } catch (e) {
      print('❌ fetchUserCollections hatası: $e');
      return [];
    }
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
