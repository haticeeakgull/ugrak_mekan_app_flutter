import 'dart:io';
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

      // Kendi koleksiyonlarına is_saved: false flag'ini ekle
      for (var col in ownCollections) {
        col['is_saved'] = false;
      }

      // 2. Kullanıcının kaydettiği koleksiyonlar (sadece kendi profilinde)
      List<dynamic> savedCollections = [];
      if (isOwnProfile) {
        debugPrint('💾 Kaydedilen koleksiyonlar sorgulanıyor...');
        debugPrint('   User ID: $userId');
        
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
        if (savedData.isNotEmpty) {
          debugPrint('   İlk kaydedilen: ${savedData[0]}');
        }

        // Kaydedilen koleksiyonları düzleştir ve "is_saved" flag'i ekle
        for (var item in savedData) {
          if (item['koleksiyonlar'] != null) {
            var collection = Map<String, dynamic>.from(item['koleksiyonlar']);
            collection['is_saved'] = true; // Kaydedilmiş koleksiyon işareti
            debugPrint('   ✅ Kaydedilen koleksiyon eklendi: ${collection['isim']} (is_saved: true)');
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

    debugPrint('🗑️ Koleksiyon kayıtlardan kaldırılıyor:');
    debugPrint('   User ID: $userId');
    debugPrint('   Collection ID: $collectionId');

    final result = await _supabase
        .from('saved_collections')
        .delete()
        .eq('user_id', userId)
        .eq('collection_id', collectionId)
        .select(); // Silinen veriyi döndür

    debugPrint('✅ Silme sonucu: $result');
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
    // colId'nin geçerli olduğundan emin ol
    if (colId.isEmpty) {
      throw 'Koleksiyon ID boş olamaz';
    }
    
    final myId = _supabase.auth.currentUser!.id;
    
    debugPrint('📤 Koleksiyon gönderiliyor:');
    debugPrint('   Sender: $myId');
    debugPrint('   Target User: $targetUserId');
    debugPrint('   Collection ID: $colId');
    debugPrint('   Collection Name: $colName');
    
    // 1. İki kullanıcı arasında chat var mı kontrol et
    final chatResponse = await _supabase
        .from('chats')
        .select()
        .or(
          'and(user_one_id.eq.$myId,user_two_id.eq.$targetUserId),and(user_one_id.eq.$targetUserId,user_two_id.eq.$myId)',
        )
        .maybeSingle();

    String chatId;
    
    if (chatResponse == null) {
      // Chat yoksa yeni oluştur
      debugPrint('   💬 Yeni chat oluşturuluyor...');
      final newChat = await _supabase
          .from('chats')
          .insert({
            'user_one_id': myId,
            'user_two_id': targetUserId,
            'last_message': '📍 Bir koleksiyon paylaştı',
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      chatId = newChat['id'];
      debugPrint('   ✅ Yeni chat oluşturuldu: $chatId');
    } else {
      chatId = chatResponse['id'];
      debugPrint('   ✅ Mevcut chat bulundu: $chatId');
      
      // Mevcut chat'in son mesaj bilgisini güncelle
      await _supabase
          .from('chats')
          .update({
            'last_message': '📍 Bir koleksiyon paylaştı',
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .eq('id', chatId);
    }
    
    // 2. Mesajı gönder
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': myId,
      'content': 'Sana bir koleksiyon gönderdi: $colName\nhttps://haticeeakgull.github.io/?koleksiyonId=$colId',
      'collection_id': colId,
    });
    
    debugPrint('✅ Koleksiyon başarıyla gönderildi');
  }

  // Kapak fotoğrafını güncelle
  Future<String> updateCoverImage(String collectionId, String imagePath) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'Giriş yapmalısınız';

    // Dosyayı Supabase Storage'a yükle
    final fileName = 'cover_${collectionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'collection_covers/$userId/$fileName';

    await _supabase.storage.from('posts').upload(
      storagePath,
      File(imagePath),
      fileOptions: const FileOptions(upsert: true),
    );

    // Public URL al
    final publicUrl = _supabase.storage.from('posts').getPublicUrl(storagePath);

    // Veritabanını güncelle
    await _supabase
        .from('koleksiyonlar')
        .update({'cover_image_url': publicUrl})
        .eq('id', collectionId);

    return publicUrl;
  }

  // Kapak fotoğrafını kaldır
  Future<void> removeCoverImage(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'Giriş yapmalısınız';

    // Veritabanından cover_image_url'i null yap
    await _supabase
        .from('koleksiyonlar')
        .update({'cover_image_url': null})
        .eq('id', collectionId);
  }
}
