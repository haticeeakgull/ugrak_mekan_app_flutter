import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'chat_detail_screen.dart';
import 'user_profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _supabase = Supabase.instance.client;
  final String myId = Supabase.instance.client.auth.currentUser!.id;
  
  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color vanilla = const Color(0xFFF2EDC2);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: vanilla,
      appBar: AppBar(
        title: const Text(
          "Mesajlar",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: deepGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.edit_square,
                color: deepGreen,
                size: 24,
              ),
              onPressed: () => _showNewChatModal(context),
              tooltip: 'Yeni Sohbet',
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('chats')
            .stream(primaryKey: ['id'])
            .order('last_message_time', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: deepGreen),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final chats = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  if (!profileSnap.hasData) {
                    return const SizedBox();
                  }
                  final profile = profileSnap.data as Map<String, dynamic>;

                  return _buildChatItem(chat, profile);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, Map<String, dynamic> profile) {
    return Dismissible(
      key: Key(chat['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Sohbeti Sil'),
            content: Text(
              '${profile['username']} ile olan sohbeti kalıcı olarak silmek istediğine emin misin?\n\nBu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          // Silme işlemini yap
          await _deleteChat(chat['id']);
          // Stream otomatik güncellenecek
          return true;
        }
        
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: deepGreen.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: deepGreen.withOpacity(0.1),
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? Icon(Icons.person, color: deepGreen, size: 28)
                : null,
          ),
          title: Text(
            profile['username'] ?? 'Kullanıcı',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              chat['last_message'] ?? "Bir mesaj gönder...",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(chat['last_message_time']),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatId: chat['id'],
                otherUser: profile,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Önce mesajları sil
      final messagesDelete = await _supabase
          .from('messages')
          .delete()
          .eq('chat_id', chatId);
      
      debugPrint('Mesajlar silindi: $messagesDelete');
      
      // Sonra chat'i sil
      final chatDelete = await _supabase
          .from('chats')
          .delete()
          .eq('id', chatId);
      
      debugPrint('Chat silindi: $chatDelete');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Sohbet kalıcı olarak silindi'),
            backgroundColor: deepGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Silme hatası: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showNewChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewChatModal(
        myId: myId,
        deepGreen: deepGreen,
        midGreen: midGreen,
        vanilla: vanilla,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: deepGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz mesaj yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir sohbet başlatmak için\n+ butonuna tıkla',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: midGreen,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        // Bugün
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Dün';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} gün önce';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

// Yeni Sohbet Modal Widget
class _NewChatModal extends StatefulWidget {
  final String myId;
  final Color deepGreen;
  final Color midGreen;
  final Color vanilla;

  const _NewChatModal({
    required this.myId,
    required this.deepGreen,
    required this.midGreen,
    required this.vanilla,
  });

  @override
  State<_NewChatModal> createState() => _NewChatModalState();
}

class _NewChatModalState extends State<_NewChatModal> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    try {
      // Karşılıklı takipleşenleri getir (arkadaşlar)
      final response = await _supabase
          .from('follows')
          .select('following_id, profiles!follows_following_id_fkey(*)')
          .eq('follower_id', widget.myId)
          .eq('status', 'following');

      if (mounted) {
        setState(() {
          _followers = response.map((item) {
            return item['profiles'] as Map<String, dynamic>;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Takip edilenler yüklenemedi: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // İsim veya username'e göre ara
      final response = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .neq('id', widget.myId)
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Arama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.vanilla,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: widget.deepGreen.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Başlık
                Row(
                  children: [
                    Icon(Icons.chat_bubble, color: widget.deepGreen, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Yeni Sohbet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Arama kutusu
                TextField(
                  controller: _searchController,
                  onChanged: _searchUsers,
                  style: TextStyle(color: widget.deepGreen),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı ara...',
                    hintStyle: TextStyle(color: widget.deepGreen.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: widget.deepGreen),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: widget.deepGreen),
                            onPressed: () {
                              _searchController.clear();
                              _searchUsers('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: widget.deepGreen.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: widget.deepGreen),
                  )
                : _isSearching && _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildFollowersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: widget.deepGreen.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz takip ettiğin kimse yok',
              style: TextStyle(
                fontSize: 16,
                color: widget.deepGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arama yaparak kullanıcı bulabilirsin',
              style: TextStyle(
                fontSize: 14,
                color: widget.midGreen,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final user = _followers[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: widget.deepGreen.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Kullanıcı bulunamadı',
              style: TextStyle(
                fontSize: 16,
                color: widget.deepGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.deepGreen.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: widget.deepGreen.withOpacity(0.1),
          backgroundImage: user['avatar_url'] != null
              ? NetworkImage(user['avatar_url'])
              : null,
          child: user['avatar_url'] == null
              ? Icon(Icons.person, color: widget.deepGreen, size: 26)
              : null,
        ),
        title: Text(
          user['username'] ?? 'Kullanıcı',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: user['full_name'] != null
            ? Text(
                user['full_name'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chat_bubble_outline,
          color: widget.deepGreen,
          size: 22,
        ),
        onTap: () => _startChat(user),
      ),
    );
  }

  void _startChat(Map<String, dynamic> otherUser) async {
    final otherUserId = otherUser['id'];

    try {
      // Mevcut sohbet var mı kontrol et
      final existingChat = await _supabase
          .from('chats')
          .select()
          .or(
            'and(user_one_id.eq.${widget.myId},user_two_id.eq.$otherUserId),and(user_one_id.eq.$otherUserId,user_two_id.eq.${widget.myId})',
          )
          .maybeSingle();

      String chatId;

      if (existingChat != null) {
        chatId = existingChat['id'];
      } else {
        // Yeni sohbet oluştur
        final newChat = await _supabase
            .from('chats')
            .insert({
              'user_one_id': widget.myId,
              'user_two_id': otherUserId,
              'last_message': 'Sohbet başladı! 👋',
              'last_message_time': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chatId = newChat['id'];
      }

      if (!mounted) return;
      
      // Modal'ı kapat
      Navigator.pop(context);

      // Chat detay ekranına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatId: chatId,
            otherUser: otherUser,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Sohbet başlatma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sohbet başlatılamadı: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
