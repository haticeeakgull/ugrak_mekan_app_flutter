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
      body: StreamBuilder(
        // 'profiles' tablosuyla join yaparak kullanıcı bilgilerini de çekiyoruz
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('receiver_id', myId)
            .order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications =
              snapshot.data as List<Map<String, dynamic>>? ?? [];

          if (notifications.isEmpty) {
            return const Center(child: Text("Henüz bir bildirim yok."));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationItem(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    // Gelecekte kullanıcı adını göstermek için FutureBuilder ile profil çekiyoruz
    return FutureBuilder(
      future: _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', notif['sender_id'])
          .single(),
      builder: (context, AsyncSnapshot profileSnapshot) {
        final profile = profileSnapshot.data;
        final String username = profile?['username'] ?? "Biri";
        final String? avatarUrl = profile?['avatar_url'];

        String message = "";
        IconData icon = Icons.notifications;
        Color iconColor = Colors.grey;

        switch (notif['type']) {
          case 'follow_request':
            message = "seni takip etmek istiyor.";
            icon = Icons.person_add_alt;
            iconColor = Colors.blue;
            break;
          case 'follow_accept':
            message = "seni takip etmeye başladı.";
            icon = Icons.check_circle_outline;
            iconColor = Colors.green;
            break;
          case 'like':
            message = "paylaşımını beğendi.";
            icon = Icons.favorite;
            iconColor = Colors.red;
            break;
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? const Icon(Icons.person) : null,
          ),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: " "),
                TextSpan(text: message),
              ],
            ),
          ),
          trailing: notif['type'] == 'follow_request'
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: _isProcessing
                          ? null
                          : () => _handleRequest(notif, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: _isProcessing
                          ? null
                          : () => _handleRequest(notif, false),
                    ),
                  ],
                )
              : Text(
                  _formatTime(notif['created_at']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
        );
      },
    );
  }

  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _handleRequest(Map<String, dynamic> notif, bool accept) async {
    setState(() => _isProcessing = true);

    try {
      if (accept) {
        // 1. Follows tablosundaki durumu 'following' yap
        await _supabase.from('follows').update({'status': 'following'}).match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });

        // 2. Kabul edildiğine dair bir bildirim daha gönderilebilir (opsiyonel)
      } else {
        // Reddettiyse follows tablosundaki isteği tamamen sil
        await _supabase.from('follows').delete().match({
          'follower_id': notif['sender_id'],
          'following_id': notif['receiver_id'],
        });
      }

      // 3. İŞLEM BİTTİĞİNDE BİLDİRİMİ SİL (Böylece ekrandan gider)
      await _supabase.from('notifications').delete().eq('id', notif['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? "İstek kabul edildi" : "İstek reddedildi"),
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
