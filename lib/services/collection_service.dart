import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionService {
  final _supabase = Supabase.instance.client;

  Future<List<dynamic>> fetchUserCollections(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final bool isOwnProfile = currentUserId == userId;
    
    try {
      // 1. Kullanıcının kendi oluşturduğu koleksiyonlar
      var ownQuery = _supabase
          .from('koleksiyonlar')
          .select('''
            *,
            koleksiyon_ogeleri (
              ilce_isimli_kafeler (
                id
              )
            ),
            profiles:user_id (
              username
            )
          ''')
          .eq('user_id', userId);
      
      // Başkasının profilindeyse sadece public olanları göster
      if (!isOwnProfile) {
        ownQuery = ownQuery.eq('is_public', true);
      }
      
      final ownCollections = await ownQuery.order('isim');
      
      debugPrint('📦 Koleksiyonlar çekildi: ${ownCollections.length} adet');
      if (ownCollections.isNotEmpty) {
        debugPrint('   İlk koleksiyon: ${ownCollections[0]}');
      }

      // 2. Kullanıcının kaydettiği koleksiyonlar (sadece kendi profilinde)
      List<dynamic> savedCollections = [];
      if (isOwnProfile) {
        final savedData = await _supabase
            .from('saved_collections')
            .select('''
              collection_id,
              koleksiyonlar:collection_id (
                *,
                koleksiyon_ogeleri (
                  ilce_isimli_kafeler (
                    id
                  )
                ),
                profiles:user_id (
                  username
                )
              )
            ''')
            .eq('user_id', userId)
            .order('saved_at', ascending: false);

        debugPrint('💾 Kaydedilen koleksiyonlar: ${savedData.length} adet');

        // Kaydedilen koleksiyonları düzleştir ve "is_saved" flag'i ekle
        for (var item in savedData) {
          if (item['koleksiyonlar'] != null) {
            var collection = Map<String, dynamic>.from(item['koleksiyonlar']);
            collection['is_saved'] = true; // Kaydedilmiş koleksiyon işareti
            savedCollections.add(collection);
          }
        }
      }

      // 3. İki listeyi birleştir
      final allCollections = [...ownCollections, ...savedCollections];

      // Her koleksiyon için kafe fotolarını çek
      for (var col in allCollections) {
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

      return allCollections;
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

  // Koleksiyonu kaydet
  Future<void> saveCollection(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'Giriş yapmalısınız';

    await _supabase.from('saved_collections').insert({
      'user_id': userId,
      'collection_id': collectionId,
    });
  }

  // Koleksiyonu kayıtlardan kaldır
  Future<void> unsaveCollection(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'Giriş yapmalısınız';

    await _supabase
        .from('saved_collections')
        .delete()
        .eq('user_id', userId)
        .eq('collection_id', collectionId);
  }

  // Koleksiyonun kaydedilip kaydedilmediğini kontrol et
  Future<bool> isCollectionSaved(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final result = await _supabase
        .from('saved_collections')
        .select()
        .eq('user_id', userId)
        .eq('collection_id', collectionId)
        .maybeSingle();

    return result != null;
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
