import 'package:flutter/material.dart';
import 'package:ugrak_mekan_app/services/onesignal_notification_service.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final OneSignalNotificationService _notificationService = OneSignalNotificationService();
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.toggleNotifications(value);
      setState(() {
        _notificationsEnabled = value;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                ? '✅ Bildirimler açıldı' 
                : '🔕 Bildirimler kapatıldı'
            ),
            backgroundColor: const Color(0xFF346739),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bildirim Açıklama Kartı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF346739).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF346739).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: const Color(0xFF346739),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Push Bildirimler',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF346739),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Yeni mesajlar, takipçiler ve yorumlar için telefonunuza bildirim alın',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bildirim Ayarları
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Tüm Bildirimler',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _notificationsEnabled
                              ? 'Bildirimler açık'
                              : 'Bildirimler kapalı',
                          style: TextStyle(
                            fontSize: 12,
                            color: _notificationsEnabled
                                ? const Color(0xFF346739)
                                : Colors.grey,
                          ),
                        ),
                        value: _notificationsEnabled,
                        activeColor: const Color(0xFF346739),
                        onChanged: _toggleNotifications,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Bildirim Türleri (Gelecekte eklenebilir)
                if (_notificationsEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Bildirim Türleri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.message,
                            color: Color(0xFF346739),
                          ),
                          title: const Text('Mesajlar'),
                          subtitle: const Text(
                            'Yeni mesaj geldiğinde bildirim al',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.check_circle, color: Color(0xFF346739)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: Color(0xFF346739),
                          ),
                          title: const Text('Takipçiler'),
                          subtitle: const Text(
                            'Yeni takipçi geldiğinde bildirim al',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.check_circle, color: Color(0xFF346739)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.comment,
                            color: Color(0xFF346739),
                          ),
                          title: const Text('Yorumlar'),
                          subtitle: const Text(
                            'Gönderilerinize yorum yapıldığında bildirim al',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.check_circle, color: Color(0xFF346739)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Bilgi Notu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bildirimleri kapatırsanız, yeni mesajlar ve güncellemeler hakkında bilgilendirilmezsiniz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
