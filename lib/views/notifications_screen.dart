import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  
  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color vanilla = const Color(0xFFFAF8F3);

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final myId = _supabase.auth.currentUser!.id;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('receiver_id', myId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint("Okundu işaretleme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _supabase.auth.currentUser!.id;

    return AppScaffold(
      backgroundColor: vanilla,
      appBar: AppBar(
        title: const Text(
          "Bildirimler",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('receiver_id', myId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: deepGreen),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) =>
                _buildNotificationItem(notifications[index]),
          );
        },
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
              Icons.notifications_none,
              size: 64,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz bildirim yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bildirimler burada görünecek',
            style: TextStyle(
              fontSize: 14,
              color: midGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    return FutureBuilder(
      future: _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', notif['sender_id'])
          .single(),
      builder: (context, AsyncSnapshot profileSnapshot) {
        if (!profileSnapshot.hasData) return const SizedBox.shrink();

        final profile = profileSnapshot.data;
        String message = "";
        IconData icon = Icons.notifications;
        Color iconColor = Colors.grey;

        // Bildirim tiplerine göre mesaj ve ikon
        switch (notif['type']) {
          case 'follow_request':
            message = "seni takip etmek istiyor";
            icon = Icons.person_add_rounded;
            iconColor = Colors.blue;
            break;
          case 'follow':
            message = "seni takip etmeye başladı";
            icon = Icons.person_add_alt_1_rounded;
            iconColor = deepGreen;
            break;
          case 'follow_accept':
            message = "takip isteğini kabul etti";
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
            break;
          case 'like':
            message = "uğrak önerini beğendi";
            icon = Icons.favorite_rounded;
            iconColor = Colors.red;
            break;
          default:
            message = "sana bir etkileşim gönderdi";
        }

        return Dismissible(
          key: Key(notif['id']),
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
            // Takip isteği bildirimleri için onay iste
            if (notif['type'] == 'follow_request') {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Bildirimi Sil'),
                  content: const Text(
                    'Bu takip isteğini silmek istediğine emin misin?\n\nİstek otomatik olarak reddedilecek.',
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
            }
            // Diğer bildirimler için direkt sil
            return true;
          },
          onDismissed: (direction) async {
            await _deleteNotification(notif);
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
                radius: 26,
                backgroundColor: deepGreen.withOpacity(0.1),
                backgroundImage: profile['avatar_url'] != null
                    ? NetworkImage(profile['avatar_url'])
                    : null,
                child: profile['avatar_url'] == null
                    ? Icon(Icons.person, color: deepGreen, size: 26)
                    : null,
              ),
              title: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: profile['username'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: " $message"),
                  ],
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(notif['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: notif['type'] == 'follow_request'
                  ? _buildRequestButtons(notif)
                  : Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: iconColor,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestButtons(Map<String, dynamic> notif) {
    return _isProcessing
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: deepGreen,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 22,
                  ),
                  onPressed: () => _handleRequest(notif, true),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: 'Kabul Et',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 22,
                  ),
                  onPressed: () => _handleRequest(notif, false),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: 'Reddet',
                ),
              ),
            ],
          );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return "Dün";
      if (diff.inDays < 7) return "${diff.inDays} gün önce";
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    if (diff.inHours > 0) return "${diff.inHours} saat önce";
    if (diff.inMinutes > 0) return "${diff.inMinutes} dakika önce";
    return "Şimdi";
  }

  Future<void> _deleteNotification(Map<String, dynamic> notif) async {
    try {
      // Eğer takip isteği bildirimi ise, takip isteğini de reddet
      if (notif['type'] == 'follow_request') {
        await _supabase.from('follows').delete().match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });
      }

      // Bildirimi sil
      await _supabase.from('notifications').delete().eq('id', notif['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Bildirim silindi'),
            backgroundColor: deepGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Bildirim silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> notif, bool accept) async {
    setState(() => _isProcessing = true);

    try {
      if (accept) {
        // Takip durumunu güncelle
        await _supabase.from('follows').update({'status': 'following'}).match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });

        // Takip edilen kişiye puan ekle (5 puan)
        await _addFollowerPoints(notif['receiver_id']);

        // Kabul bildirimini gönder
        await _supabase.from('notifications').insert({
          'sender_id': notif['receiver_id'],
          'receiver_id': notif['sender_id'],
          'type': 'follow_accept',
          'is_read': false,
        });
      } else {
        // Takip isteğini sil
        await _supabase.from('follows').delete().match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });
      }

      // Bildirimi sil
      await _supabase.from('notifications').delete().eq('id', notif['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? '✅ İstek kabul edildi' : '❌ İstek reddedildi'),
            backgroundColor: accept ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("İşlem hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Takipçi puanı ekle (5 puan)
  Future<void> _addFollowerPoints(String userId) async {
    try {
      // Mevcut puanları al
      final profile = await _supabase
          .from('profiles')
          .select('weekly_points')
          .eq('id', userId)
          .single();

      final currentPoints = profile['weekly_points'] ?? 0;
      final newPoints = currentPoints + 5;

      // Puanı güncelle
      await _supabase
          .from('profiles')
          .update({'weekly_points': newPoints})
          .eq('id', userId);

      debugPrint('✅ Takipçi puanı eklendi: +5 puan (Toplam: $newPoints)');
    } catch (e) {
      debugPrint('❌ Takipçi puanı ekleme hatası: $e');
    }
  }
}
