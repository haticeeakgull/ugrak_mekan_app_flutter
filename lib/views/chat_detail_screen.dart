import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';

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

  // Mesaj gönderme fonksiyonu
  void _sendMessage({String? text, String? collectionId}) async {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty && collectionId == null) return;

    try {
      await _supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': myId,
        'content': content,
        'collection_id': collectionId, // Koleksiyon ID'si varsa ekle
      });

      // Sohbet listesindeki 'son mesaj' bilgisini güncelle
      await _supabase
          .from('chats')
          .update({
            'last_message': collectionId != null
                ? "📍 Bir koleksiyon paylaştı"
                : content,
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.chatId);

      _messageController.clear(); // Yazı alanını temizle
    } catch (e) {
      debugPrint("Mesaj gönderme hatası: $e");
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
              backgroundColor: const Color(0xFF346739),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(),
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
            const Text(
              "Çevrimiçi",
              style: TextStyle(color: Colors.green, fontSize: 12),
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
                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true, // En yeni mesaj en altta
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == myId;

                    return _buildMessageBubble(msg, isMe);
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

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final bool isCollection = msg['collection_id'] != null;

    return GestureDetector(
      onTap: isCollection
          ? () {
              // Koleksiyon ID'sini alıp detay sayfasına yönlendiriyoruz
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CollectionDetailScreen(
                    collectionId: msg['collection_id'].toString(),
                    collectionName: '',
                  ),
                ),
              );
            }
          : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
                    ? Border.all(color: const Color(0xFF9FCB98).withValues(alpha: 0.5))
                    : null,
              ),
              child: isCollection
                  ? _buildCollectionCard(msg['content'], msg['collection_id']?.toString()) // Koleksiyon görünümü
                  : Text(
                      msg['content'],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
            ),
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
    return FutureBuilder<List<String>>(
      future: _fetchCollectionPhotos(collectionId),
      builder: (context, snapshot) {
        final photos = snapshot.data ?? [];
        return _buildCollectionCardUI(content, photos);
      },
    );
  }

  Future<List<String>> _fetchCollectionPhotos(String? collectionId) async {
    if (collectionId == null) return [];
    try {
      final col = await _supabase
          .from('koleksiyonlar')
          .select('''
            id,
            koleksiyon_ogeleri (
              ilce_isimli_kafeler (id)
            )
          ''')
          .eq('id', collectionId)
          .maybeSingle();

      if (col == null) return [];

      List<String> photos = [];
      final items = col['koleksiyon_ogeleri'] as List? ?? [];

      for (var i = 0; i < items.length && i < 4; i++) {
        final cafe = items[i]['ilce_isimli_kafeler'];
        if (cafe == null) continue;

        final postFoto = await _supabase
            .from('cafe_postlar')
            .select('foto_url')
            .eq('cafe_id', cafe['id'])
            .not('foto_url', 'is', null)
            .limit(1)
            .maybeSingle();

        if (postFoto != null && postFoto['foto_url'] != null) {
          final url = postFoto['foto_url'] as String;
          if (!url.contains('googleapis')) {
            photos.add(url);
          }
        }
      }
      return photos;
    } catch (e) {
      return [];
    }
  }

  Widget _buildCollectionCardUI(String content, List<String> photos) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto alanı
            SizedBox(
              height: 130,
              width: double.infinity,
              child: photos.isEmpty
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF346739), Color(0xFF79AE6F)],
                        ),
                      ),
                      child: const Icon(
                        Icons.collections_bookmark_rounded,
                        color: Colors.white54,
                        size: 44,
                      ),
                    )
                  : photos.length == 1
                  ? Image.network(
                      photos[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _greenGradientBox(),
                    )
                  : _buildPhotoGrid(photos),
            ),
            // Alt bilgi
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF346739).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "📍 Koleksiyon",
                          style: TextStyle(
                            color: Color(0xFF346739),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: Color(0xFF79AE6F),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Görüntülemek için tıkla",
                        style: TextStyle(
                          color: Color(0xFF79AE6F),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _greenGradientBox() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF346739), Color(0xFF79AE6F)],
        ),
      ),
      child: const Icon(
        Icons.collections_bookmark_rounded,
        color: Colors.white54,
        size: 44,
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos) {
    if (photos.length == 2) {
      return Row(
        children: photos
            .map(
              (url) => Expanded(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  height: 130,
                  errorBuilder: (_, __, ___) => _greenGradientBox(),
                ),
              ),
            )
            .toList(),
      );
    }
    // 3-4 foto: büyük sol + sağda 2-3 küçük
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Image.network(
            photos[0],
            fit: BoxFit.cover,
            height: 130,
            errorBuilder: (_, __, ___) => _greenGradientBox(),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            children: [
              for (var i = 1; i < photos.length && i < 4; i++) ...[
                if (i > 1) const SizedBox(height: 2),
                Expanded(
                  child: Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => _greenGradientBox(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
              future: _supabase
                  .from('koleksiyonlar')
                  .select('''
                    id, isim,
                    koleksiyon_ogeleri (
                      ilce_isimli_kafeler (id)
                    )
                  ''')
                  .eq('user_id', myId),
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
}
