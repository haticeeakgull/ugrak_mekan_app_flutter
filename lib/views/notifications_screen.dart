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
    _markAllAsRead(); // Sayfa açılınca bildirimleri "okundu" yap
  }

  Future<void> _markAllAsRead() async {
    final myId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('receiver_id', myId)
        .eq('is_read', false);
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
      body: StreamBuilder(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('receiver_id', myId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final notifications = snapshot.data as List<Map<String, dynamic>>;
          if (notifications.isEmpty)
            return const Center(child: Text("Henüz bir bildirim yok."));

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

        switch (notif['type']) {
          case 'follow_request':
            message = "seni takip etmek istiyor.";
            icon = Icons.person_add;
            break;
          case 'follow_accept':
            message = "takip isteğini kabul etti.";
            icon = Icons.check_circle;
            break;
          case 'like':
            message = "önerini beğendi.";
            icon = Icons.favorite;
            break;
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? const Icon(Icons.person)
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
          trailing: notif['type'] == 'follow_request'
              ? _buildRequestButtons(notif)
              : Text(
                  _formatTime(notif['created_at']),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
        );
      },
    );
  }

  Widget _buildRequestButtons(Map<String, dynamic> notif) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          onPressed: () => _handleRequest(notif, true),
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () => _handleRequest(notif, false),
        ),
      ],
    );
  }

  // _handleRequest ve _formatTime fonksiyonların senin eski kodunla aynı kalabilir...
  String _formatTime(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    if (now.difference(dt).inDays > 0) return "${now.difference(dt).inDays}g";
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
