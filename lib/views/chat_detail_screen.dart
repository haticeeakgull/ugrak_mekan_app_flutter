import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';

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
                color: Colors.deepOrange,
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
              backgroundColor: Colors.deepOrange,
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
    return Scaffold(
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
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
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
                    ? Colors
                          .white // Koleksiyon kartı beyaz olsun
                    : (isMe ? Colors.deepOrange : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isCollection
                    ? Border.all(color: Colors.orange.shade100)
                    : null,
              ),
              child: isCollection
                  ? _buildCollectionCard(msg['content']) // Koleksiyon görünümü
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
  Widget _buildCollectionCard(String content) {
    return Column(
      children: [
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Icon(Icons.map_rounded, size: 40, color: Colors.orange),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📍 Koleksiyon Paylaşıldı",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(),
              const Center(
                child: Text(
                  "Görüntülemek için tıkla",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCollectionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder(
        future: _supabase.from('koleksiyonlar').select().eq('user_id', myId),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final collections = snapshot.data as List;

          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, i) {
              final col = collections[i];
              return ListTile(
                leading: const Icon(Icons.folder_special, color: Colors.orange),
                title: Text(col['isim']),
                onTap: () {
                  // Sadece koleksiyon ID'sini ve ismini gönderiyoruz
                  _sendMessage(
                    text: "📍 '${col['isim']}' koleksiyonumu seninle paylaştı.",
                    collectionId: col['id'].toString(),
                  );
                  Navigator.pop(context); // Seçim yapınca modalı kapat
                },
              );
            },
          );
        },
      ),
    );
  }
}
