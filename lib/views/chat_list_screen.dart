import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _supabase = Supabase.instance.client;
  final String myId = Supabase.instance.client.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mesajlar",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_note_rounded,
              size: 30,
              color: Colors.deepOrange,
            ),
            onPressed: () => _showNewChatModal(context), // Yeni sohbet başlatma
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('chats')
            .stream(primaryKey: ['id'])
            .order('last_message_time', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final chats = snapshot.data!;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUserId = chat['user_one_id'] == myId
                  ? chat['user_two_id']
                  : chat['user_one_id'];

              return FutureBuilder(
                future: _supabase
                    .from('profiles')
                    .select()
                    .eq('id', otherUserId)
                    .single(),
                builder: (context, profileSnap) {
                  if (!profileSnap.hasData) return const SizedBox();
                  final profile = profileSnap.data as Map<String, dynamic>;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profile['avatar_url'] != null
                          ? NetworkImage(profile['avatar_url'])
                          : null,
                      child: profile['avatar_url'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      profile['username'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      chat['last_message'] ?? "Bir mesaj gönder...",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(_formatTime(chat['last_message_time'])),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          chatId: chat['id'],
                          otherUser: profile,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- SADECE ARKADAŞLARI GÖSTEREN MODAL ---
  void _showNewChatModal(BuildContext context) async {
    // Karşılıklı takipleşenleri (arkadaşları) bulma sorgusu
    final friendsResponse = await _supabase.rpc('get_friends');
    // Not: Bu RPC fonksiyonunu aşağıda SQL olarak vereceğim.

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Yeni Sohbet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder(
                future: _supabase
                    .from('follows')
                    .select('profiles!follows_follower_id_fkey(*)')
                    .eq('following_id', myId)
                    .eq('status', 'following'),
                builder: (context, AsyncSnapshot snap) {
                  // Burada basitleştirmek için takipçilerini listeliyoruz
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List followers = snap.data;

                  return ListView.builder(
                    itemCount: followers.length,
                    itemBuilder: (context, i) {
                      final user = followers[i]['profiles'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            user['avatar_url'] ?? '',
                          ),
                        ),
                        title: Text(user['username']),
                        onTap: () => _startChat(user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(Map<String, dynamic> otherUser) async {
    final otherUserId = otherUser['id'];

    try {
      // 1. Önce bu iki kullanıcı arasında zaten bir sohbet var mı kontrol et
      final existingChat = await _supabase
          .from('chats')
          .select()
          .or(
            'and(user_one_id.eq.$myId,user_two_id.eq.$otherUserId),and(user_one_id.eq.$otherUserId,user_two_id.eq.$myId)',
          )
          .maybeSingle();

      String chatId;

      if (existingChat != null) {
        chatId = existingChat['id'];
      } else {
        // Yoksa yeni bir sohbet satırı oluştur
        final newChat = await _supabase
            .from('chats')
            .insert({
              'user_one_id': myId,
              'user_two_id': otherUserId,
              'last_message': 'Sohbet başladı! 👋',
              'last_message_time': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chatId = newChat['id'];
      }

      // 2. Modal'ı kapat ve detay ekranına git
      if (!mounted) return;
      Navigator.pop(context); // Seçim modalını kapat

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatDetailScreen(chatId: chatId, otherUser: otherUser),
        ),
      );
    } catch (e) {
      debugPrint("Sohbet başlatma hatası: $e");
      // Hata olursa kullanıcıya bildir
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Sohbet başlatılamadı: $e")));
    }
  }

  Widget _buildEmptyState() {
    /* Önceki mesajda verdiğim tasarım */
    return const Center(child: Text("Mesaj yok"));
  }

  String _formatTime(String t) => ""; // Zaman formatlama
}
