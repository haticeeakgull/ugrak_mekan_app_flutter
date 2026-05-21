import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'package:ugrak_mekan_app/services/onesignal_notification_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> otherUser;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final String myId = Supabase.instance.client.auth.currentUser!.id;
  final _notificationService = OneSignalNotificationService();
  bool _isSending = false; // Mesaj gönderme durumu
  String? _tappedMessageId; // Tıklanan mesajın ID'si (timestamp göstermek için)

  // Mesaj gönderme fonksiyonu
  void _sendMessage({String? text, String? collectionId}) async {
    // Eğer zaten gönderiliyor ise, tekrar gönderme
    if (_isSending) {
      debugPrint('⚠️ Mesaj zaten gönderiliyor, bekleyin...');
      return;
    }

    final content = text ?? _messageController.text.trim();
    
    debugPrint('📤 Mesaj gönderiliyor...');
    debugPrint('   Content: $content');
    debugPrint('   Collection ID: $collectionId');
    debugPrint('   Chat ID: ${widget.chatId}');
    debugPrint('   Sender ID: $myId');
    
    if (content.isEmpty && collectionId == null) {
      debugPrint('❌ İçerik boş, mesaj gönderilmedi');
      return;
    }

    // Gönderme durumunu aktif et
    setState(() => _isSending = true);

    try {
      debugPrint('🔄 Supabase\'e mesaj ekleniyor...');
      await _supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': myId,
        'content': content,
        'collection_id': collectionId, // Koleksiyon ID'si varsa ekle
      });
      debugPrint('✅ Mesaj Supabase\'e eklendi');

      // Sohbet listesindeki 'son mesaj' bilgisini güncelle
      debugPrint('🔄 Chat güncelleniyor...');
      await _supabase.from('chats').update({
        'last_message':
            collectionId != null ? "📍 Bir koleksiyon paylaştı" : content,
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', widget.chatId);
      debugPrint('✅ Chat güncellendi');

      // Push notification gönder
      final myProfile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', myId)
          .single();

      final messageText = collectionId != null 
          ? "📍 Bir koleksiyon paylaştı" 
          : content;

      await _notificationService.sendMessageNotification(
        senderId: myId,
        receiverId: widget.otherUser['id'],
        senderUsername: myProfile['username'] ?? 'Bir kullanıcı',
        messageText: messageText,
        chatId: widget.chatId,
      );

      _messageController.clear(); // Yazı alanını temizle
      debugPrint('✅ Mesaj başarıyla gönderildi!');
    } catch (e) {
      debugPrint("❌ Mesaj gönderme hatası: $e");
      
      // Kullanıcıya hata göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj gönderilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Gönderme durumunu pasif et
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // Mesaj yazma kutusu tasarımı
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // KOLEKSİYON PAYLAŞMA BUTONU
            IconButton(
              icon: const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF346739),
              ),
              onPressed: _showCollectionPicker,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Mesajınızı yazın...",
                  filled: true,
                  fillColor: const Color.fromARGB(255, 255, 255, 255),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // GÖNDER BUTONU
            CircleAvatar(
              backgroundColor: _isSending 
                  ? Colors.grey 
                  : const Color(0xFF346739),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isSending ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color.fromARGB(255, 255, 254, 254),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 249, 248, 248),
        elevation: 0.5,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(Icons.chevron_left, color: Colors.black),
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.otherUser['avatar_url'] != null
                    ? NetworkImage(widget.otherUser['avatar_url'])
                    : null,
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUser['username'],
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', widget.chatId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Silinen mesajları filtrele
                final allMessages = snapshot.data!;
                final messages = allMessages.where((msg) {
                  // Herkesten silinmiş mi?
                  if (msg['deleted_for_everyone'] == true) {
                    return false;
                  }

                  // Ben gönderdim ve benim için silinmiş mi?
                  if (msg['sender_id'] == myId &&
                      msg['deleted_for_sender'] == true) {
                    return false;
                  }

                  // Karşı taraf gönderdi ve benim için (alıcı olarak) silinmiş mi?
                  if (msg['sender_id'] != myId &&
                      msg['deleted_for_receiver'] == true) {
                    return false;
                  }

                  return true;
                }).toList();

                return ListView.builder(
                  reverse: true, // En yeni mesaj en altta
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == myId;

                    // Mesaj gruplama mantığı: bir sonraki mesaj aynı kişiden mi?
                    final bool isLastInGroup = index == 0 || 
                        messages[index - 1]['sender_id'] != msg['sender_id'];

                    return _buildMessageBubble(msg, isMe, isLastInGroup);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool isLastInGroup) {
    final bool isCollection = msg['collection_id'] != null;
    final String messageId = msg['id'].toString();
    final bool showTimestamp = _tappedMessageId == messageId || isLastInGroup;

    return GestureDetector(
      onTap: isCollection
          ? () async {
              // Koleksiyon bilgisini çek
              try {
                final collection = await _supabase
                    .from('koleksiyonlar')
                    .select('user_id, isim')
                    .eq('id', msg['collection_id'])
                    .maybeSingle();

                if (mounted && collection != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollectionDetailScreen(
                        collectionId: msg['collection_id'].toString(),
                        collectionName: collection['isim'] ?? 'Koleksiyon',
                        ownerId: collection['user_id']?.toString(),
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Koleksiyon bilgisi alınamadı: $e');
              }
            }
          : () {
              // Normal mesaj: timestamp'i göster/gizle
              setState(() {
                if (_tappedMessageId == messageId) {
                  _tappedMessageId = null; // Zaten gösteriliyorsa gizle
                } else {
                  _tappedMessageId = messageId; // Göster
                }
              });
            },
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(
                isCollection ? 0 : 12,
              ), // Koleksiyon ise padding iç kutuda olacak
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isCollection
                    ? Colors.white
                    : (isMe ? const Color(0xFF346739) : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isCollection
                    ? Border.all(
                        color: const Color(0xFF9FCB98).withValues(alpha: 0.5))
                    : null,
              ),
              child: isCollection
                  ? _buildCollectionCard(msg['content'],
                      msg['collection_id']?.toString()) // Koleksiyon görünümü
                  : Text(
                      msg['content'],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
            ),
            // Timestamp sadece grup içindeki son mesajda veya tıklanmışsa göster
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  timeago.format(DateTime.parse(msg['created_at']), locale: 'tr'),
                  style: const TextStyle(color: Colors.black38, fontSize: 10),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // Koleksiyonlar için özel görsel kart tasarımı
  Widget _buildCollectionCard(String content, String? collectionId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchCollectionData(collectionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(content);
        }

        final collectionData = snapshot.data;
        if (collectionData == null) {
          return _buildErrorCard(content);
        }

        return _buildCollectionPreviewCard(collectionData);
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchCollectionData(
      String? collectionId) async {
    if (collectionId == null) return null;

    try {
      // 1. Koleksiyon bilgilerini çek
      final collection = await _supabase.from('koleksiyonlar').select('''
            id,
            isim,
            is_public,
            user_id,
            koleksiyon_ogeleri (
              ilce_isimli_kafeler (id)
            )
          ''').eq('id', collectionId).maybeSingle();

      if (collection == null) return null;

      // 2. Kullanıcı bilgisini ayrı çek
      String ownerUsername = 'Anonim';
      String? ownerAvatarUrl;

      if (collection['user_id'] != null) {
        try {
          final profile = await _supabase
              .from('profiles')
              .select('username, avatar_url')
              .eq('id', collection['user_id'])
              .maybeSingle();

          if (profile != null) {
            ownerUsername = profile['username'] ?? 'Anonim';
            ownerAvatarUrl = profile['avatar_url'];
          }
        } catch (e) {
          debugPrint('Profil bilgisi alınamadı: $e');
        }
      }

      // 3. Kafe fotoğraflarını çek
      List<String> photos = [];
      final items = collection['koleksiyon_ogeleri'] as List? ?? [];
      final cafeCount = items.length;

      for (var i = 0; i < items.length && i < 4; i++) {
        final cafe = items[i]['ilce_isimli_kafeler'];
        if (cafe == null) continue;

        // Önce kullanıcı postlarından fotoğraf ara
        final postFoto = await _supabase
            .from('cafe_postlar')
            .select('foto_url')
            .eq('cafe_id', cafe['id'])
            .not('foto_url', 'is', null)
            .limit(1)
            .maybeSingle();

        if (postFoto != null && postFoto['foto_url'] != null) {
          photos.add(postFoto['foto_url'] as String);
        } else {
          // Post yoksa, cafe_fotograflar tablosundan Google fotoğraflarını çek
          final googlePhotos = await _supabase
              .from('cafe_fotograflar')
              .select('foto_url')
              .eq('cafe_id', cafe['id'])
              .limit(1)
              .maybeSingle();

          // Yoksa cafe_fotograflar'dan dene (Supabase Storage)
          final cafePhotos = await _supabase
              .from('cafe_fotograflar')
              .select('foto_url')
              .eq('cafe_id', cafe['id'])
              .limit(1)
              .maybeSingle();

          if (cafePhotos != null && cafePhotos['foto_url'] != null) {
            photos.add(cafePhotos['foto_url'] as String);
          }
        }
      }

      return {
        'id': collection['id'],
        'name': collection['isim'] ?? 'Koleksiyon',
        'isPublic': collection['is_public'] ?? true,
        'cafeCount': cafeCount,
        'photos': photos,
        'ownerUsername': ownerUsername,
        'ownerAvatarUrl': ownerAvatarUrl,
        'ownerId': collection['user_id'],
      };
    } catch (e) {
      debugPrint('Koleksiyon verisi çekilemedi: $e');
      return null;
    }
  }

  Widget _buildCollectionPreviewCard(Map<String, dynamic> data) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fotoğraf bölümü
            SizedBox(
              height: 180,
              width: double.infinity,
              child: _buildImageSection(data['photos'] as List<String>),
            ),
            // Bilgi bölümü
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Koleksiyon ismi
                  Text(
                    data['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF346739),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Kafe sayısı ve görünürlük
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF79AE6F).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF346739),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data['cafeCount']} Kafe',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF346739),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (data['isPublic'])
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF346739).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.public,
                                size: 12,
                                color: Color(0xFF346739),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Açık',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF346739),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Kullanıcı bilgisi
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            const Color(0xFF79AE6F).withOpacity(0.2),
                        backgroundImage: data['ownerAvatarUrl'] != null
                            ? NetworkImage(data['ownerAvatarUrl'])
                            : null,
                        child: data['ownerAvatarUrl'] == null
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFF346739),
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '@${data['ownerUsername']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF346739),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Color(0xFF79AE6F),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF79AE6F), Color(0xFF346739)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.bookmark_rounded,
            size: 60,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      );
    }

    // 1 foto: tam ekran
    if (photos.length == 1) {
      return Image.network(
        photos[0],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultBackground(),
      );
    }

    // 2-4 foto: grid layout
    final photoCount = photos.length > 4 ? 4 : photos.length;

    return Row(
      children: [
        // Sol: ilk foto (büyük)
        Expanded(
          child: Image.network(
            photos[0],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF79AE6F).withOpacity(0.5),
            ),
          ),
        ),
        // Sağ: diğer fotolar
        if (photoCount > 1)
          Expanded(
            child: Column(
              children: [
                for (int i = 1; i < photoCount; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: 2,
                        top: i > 1 ? 2 : 0,
                      ),
                      child: Image.network(
                        photos[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF79AE6F).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF79AE6F), Color(0xFF346739)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.bookmark_rounded,
          size: 60,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(String content) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9FCB98).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF346739),
            strokeWidth: 2,
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String content) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Koleksiyon yüklenemedi',
            style: TextStyle(
              fontSize: 11,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showCollectionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Koleksiyon Paylaş",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            FutureBuilder(
              future: _supabase.from('koleksiyonlar').select('''
                    id, isim,
                    koleksiyon_ogeleri (
                      ilce_isimli_kafeler (id)
                    )
                  ''').eq('user_id', myId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF346739)),
                  );
                }
                final collections = snapshot.data as List;
                if (collections.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("Henüz koleksiyonun yok."),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: collections.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final col = collections[i];
                    final itemCount =
                        (col['koleksiyon_ogeleri'] as List?)?.length ?? 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF346739).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.collections_bookmark_rounded,
                          color: Color(0xFF346739),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        col['isim'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "$itemCount mekan",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF346739),
                      ),
                      onTap: () {
                        _sendMessage(
                          text: col['isim'],
                          collectionId: col['id'].toString(),
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Mesaj seçenekleri dialog'u
  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // Kendim için sil
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('Benim İçin Sil'),
              subtitle: const Text('Sadece sizin için silinir'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(msg['id']);
              },
            ),

            // Herkesten sil (sadece gönderen görebilir)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Herkesten Sil'),
                subtitle: const Text('Herkes için silinir'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteForEveryoneConfirmation(msg['id']);
                },
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Herkesten silme onayı
  void _showDeleteForEveryoneConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Herkesten Sil?'),
        content: const Text(
          'Bu mesaj herkes için silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessageForEveryone(messageId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Mesajı sadece kendim için sil
  Future<void> _deleteMessageForMe(String messageId) async {
    try {
      debugPrint('🗑️ Mesaj siliniyor (benim için): $messageId');

      final result = await _supabase.rpc(
        'delete_message_for_user',
        params: {
          'p_message_id': messageId,
          'p_user_id': _supabase.auth.currentUser!.id,
          'p_delete_for_everyone': false,
        },
      );

      debugPrint('✅ Silme sonucu: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mesaj silindi'),
            backgroundColor: Color(0xFF346739),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Mesaj silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mesajı herkesten sil
  Future<void> _deleteMessageForEveryone(String messageId) async {
    try {
      debugPrint('🗑️ Mesaj siliniyor (herkesten): $messageId');

      final result = await _supabase.rpc(
        'delete_message_for_user',
        params: {
          'p_message_id': messageId,
          'p_user_id': _supabase.auth.currentUser!.id,
          'p_delete_for_everyone': true,
        },
      );

      debugPrint('✅ Silme sonucu: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mesaj herkesten silindi'),
            backgroundColor: Color(0xFF346739),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Mesaj silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
