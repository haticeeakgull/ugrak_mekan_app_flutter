import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _markAllAsRead(); // Sayfa açılınca okunmamış bildirimleri işaretle
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Etkinlik",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
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
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Henüz bir bildirim yok.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) =>
                _buildNotificationItem(notifications[index]),
          );
        },
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

        // BİLDİRİM TİPLERİNE GÖRE MESAJ VE İKON AYARI
        switch (notif['type']) {
          case 'follow_request':
            message = "seni takip etmek istiyor.";
            icon = Icons.person_add_rounded;
            iconColor = Colors.blue;
            break;
          case 'follow':
            message = "seni takip etmeye başladı.";
            icon = Icons.person_add_alt_1_rounded;
            iconColor = Colors.deepOrange;
            break;
          case 'follow_accept':
            message = "takip isteğini kabul etti.";
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
            break;
          case 'like':
            message = "uğrak önerini beğendi.";
            icon = Icons.favorite_rounded;
            iconColor = Colors.red;
            break;
          default:
            message = "sana bir etkileşim gönderdi.";
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: profile['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: " $message"),
              ],
            ),
          ),
          // Sadece 'follow_request' tipinde butonları göster
          trailing: notif['type'] == 'follow_request'
              ? _buildRequestButtons(notif)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(notif['created_at']),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Icon(icon, size: 16, color: iconColor.withOpacity(0.7)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRequestButtons(Map<String, dynamic> notif) {
    return _isProcessing
        ? const SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),
                onPressed: () => _handleRequest(notif, true),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                onPressed: () => _handleRequest(notif, false),
              ),
            ],
          );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) return "${diff.inDays}g";
    if (diff.inHours > 0) return "${diff.inHours}sa";
    if (diff.inMinutes > 0) return "${diff.inMinutes}dk";
    return "Şimdi";
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

        // İsteği kabul ettiğine dair karşı tarafa bildirim gönder (Opsiyonel)
        await _supabase.from('notifications').insert({
          'sender_id': notif['receiver_id'],
          'receiver_id': notif['sender_id'],
          'type': 'follow_accept',
          'is_read': false,
        });
      } else {
        // Reddedildiyse takip isteğini tamamen sil
        await _supabase.from('follows').delete().match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });
      }

      // Mevcut bildirim kaydını silerek ekrandan kaldır
      await _supabase.from('notifications').delete().eq('id', notif['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? "İstek kabul edildi" : "İstek reddedildi"),
            backgroundColor: accept ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("İşlem hatası: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
