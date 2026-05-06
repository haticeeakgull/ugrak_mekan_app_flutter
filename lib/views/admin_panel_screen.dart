import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

/// Admin Panel - Eksik Kafe Bildirimleri Yönetimi
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _bildirimler = [];
  bool _isLoading = true;
  String _selectedFilter = 'istekler'; // beklemede yerine istekler

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color vanilla = const Color(0xFFFAF8F3);

  @override
  void initState() {
    super.initState();
    _loadBildirimler();
  }

  Future<void> _loadBildirimler() async {
    setState(() => _isLoading = true);
    
    try {
      List<dynamic> data;
      
      // İstekler: beklemede VE inceleniyor
      if (_selectedFilter == 'istekler') {
        data = await _supabase
            .from('eksik_kafe_bildirimleri')
            .select('*')
            .inFilter('durum', ['beklemede', 'inceleniyor'])
            .order('created_at', ascending: false);
      } else {
        // Onaylananlar veya Reddedilenler
        final durumMap = {
          'onaylananlar': 'eklendi',
          'reddedilenler': 'reddedildi',
        };
        data = await _supabase
            .from('eksik_kafe_bildirimleri')
            .select('*')
            .eq('durum', durumMap[_selectedFilter]!)
            .order('created_at', ascending: false);
      }

      // Email bilgilerini ayrı çek
      final List<Map<String, dynamic>> enrichedData = [];
      for (var item in data) {
        final userId = item['kullanici_id'];
        
        // Önce profiles'dan username dene
        final profile = await _supabase
            .from('profiles')
            .select('username')
            .eq('id', userId)
            .maybeSingle();
        
        enrichedData.add({
          ...item,
          'user_info': {
            'username': profile?['username'] ?? 'Bilinmiyor',
          }
        });
      }

      setState(() {
        _bildirimler = enrichedData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Bildirimler yüklenemedi: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Hata: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteBildirim(String id, String kafeAdi) async {
    // Onay dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bildirimi Sil'),
        content: Text(
          '"$kafeAdi" bildirimini kalıcı olarak silmek istediğine emin misin?',
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

    if (confirm != true) return;

    try {
      debugPrint('🔄 Silme işlemi başlatılıyor - ID: $id');
      
      // Veritabanından sil - count kullanarak silinen satır sayısını al
      final response = await _supabase
          .from('eksik_kafe_bildirimleri')
          .delete()
          .eq('id', id)
          .select();

      debugPrint('✅ Silme yanıtı: $response');

      // UI'dan kaldır
      if (mounted) {
        setState(() {
          _bildirimler.removeWhere((item) => item['id'] == id);
        });
        _showSnackBar('✅ Bildirim kalıcı olarak silindi');
      }
    } catch (e) {
      debugPrint('❌ Silme hatası - ID: $id, Hata: $e');
      if (mounted) {
        _showSnackBar('❌ Silme hatası: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _updateDurum(String id, String yeniDurum) async {
    try {
      await _supabase
          .from('eksik_kafe_bildirimleri')
          .update({'durum': yeniDurum})
          .eq('id', id);

      _showSnackBar('✅ Durum güncellendi: $yeniDurum');
      _loadBildirimler();
    } catch (e) {
      _showSnackBar('❌ Hata: ${e.toString()}', isError: true);
    }
  }

  Future<void> _exportToCSV() async {
    try {
      // Seçili filtredeki bildirimleri CSV formatına çevir
      final csvData = _generateCSV(_bildirimler);
      
      // Clipboard'a kopyala
      await Clipboard.setData(ClipboardData(text: csvData));
      
      _showSnackBar('✅ CSV verisi panoya kopyalandı! Python script\'ine yapıştırabilirsin.');
    } catch (e) {
      _showSnackBar('❌ CSV oluşturulamadı: ${e.toString()}', isError: true);
    }
  }

  String _generateCSV(List<Map<String, dynamic>> data) {
    final buffer = StringBuffer();
    
    // Header - sadece 3 kolon
    buffer.writeln('kafe_adi,latitude,longitude');
    
    // Rows - sadece 3 alan
    for (var item in data) {
      buffer.writeln(
        '"${item['kafe_adi']}",'
        '${item['latitude']},'
        '${item['longitude']}'
      );
    }
    
    return buffer.toString();
  }

  Future<void> _exportToJSON() async {
    try {
      // JSON formatında export - sadece 3 alan
      final jsonData = jsonEncode(_bildirimler.map((item) => {
        'kafe_adi': item['kafe_adi'],
        'latitude': item['latitude'],
        'longitude': item['longitude'],
      }).toList());
      
      await Clipboard.setData(ClipboardData(text: jsonData));
      
      _showSnackBar('✅ JSON verisi panoya kopyalandı!');
    } catch (e) {
      _showSnackBar('❌ JSON oluşturulamadı: ${e.toString()}', isError: true);
    }
  }

  Future<void> _exportSingleToJSON(Map<String, dynamic> bildirim) async {
    try {
      // Tek bildirim için JSON - sadece 3 alan
      final jsonData = jsonEncode({
        'kafe_adi': bildirim['kafe_adi'],
        'latitude': bildirim['latitude'],
        'longitude': bildirim['longitude'],
      });
      
      await Clipboard.setData(ClipboardData(text: jsonData));
      
      _showSnackBar(
        '✅ "${bildirim['kafe_adi']}" Python\'a gönderildi!\n'
        'JSON panoya kopyalandı. Python script\'ine yapıştır.',
      );

      // Kullanıcıya talimat göster
      _showPythonInstructions(bildirim['id']);
    } catch (e) {
      _showSnackBar('❌ Hata: ${e.toString()}', isError: true);
    }
  }

  void _showPythonInstructions(String bildirimId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.code, color: deepGreen),
            const SizedBox(width: 12),
            const Text('Python İşleme Adımları'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStep('1', 'JSON panoya kopyalandı'),
              _buildStep('2', 'Python script\'ini aç'),
              _buildStep('3', 'JSON\'u yapıştır'),
              _buildStep('4', 'Google Maps API\'den veri çek'),
              _buildStep('5', 'SBERT embedding oluştur'),
              _buildStep('6', 'ilce_isimli_kafeler tablosuna ekle'),
              _buildStep('7', 'Bu bildirimi "Eklendi" olarak işaretle'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDurum(bildirimId, 'eklendi');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: deepGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('İşlendi, "Eklendi" Yap'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: deepGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : deepGreen,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showOnMap(double lat, double lng, String kafeAdi) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Başlık
              Row(
                children: [
                  Icon(Icons.location_on, color: deepGreen, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kafeAdi,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: deepGreen,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Harita
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lng),
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('cafe_location'),
                        position: LatLng(lat, lng),
                        infoWindow: InfoWindow(title: kafeAdi),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Google Maps'te aç butonu
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: 'https://www.google.com/maps?q=$lat,$lng',
                  ));
                  _showSnackBar('📍 Google Maps linki kopyalandı!');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Google Maps\'te Aç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vanilla,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.w900, color: deepGreen),
        ),
        backgroundColor: Colors.white,
        foregroundColor: deepGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBildirimler,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre ve Export Butonları
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: midGreen.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Durum Filtreleri
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('istekler', '📋 İstekler'),
                      _buildFilterChip('onaylananlar', '✅ Onaylananlar'),
                      _buildFilterChip('reddedilenler', '❌ Reddedilenler'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Export Butonları
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _bildirimler.isEmpty ? null : _exportToJSON,
                        icon: const Icon(Icons.code, size: 18),
                        label: const Text('JSON Export'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepGreen.withOpacity(0.1),
                          foregroundColor: deepGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _bildirimler.isEmpty ? null : _exportToCSV,
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('CSV Export'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepGreen.withOpacity(0.1),
                          foregroundColor: deepGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bildirim Listesi
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: deepGreen),
                  )
                : _bildirimler.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bildirimler.length,
                        itemBuilder: (context, index) {
                          return _buildBildirimCard(_bildirimler[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
          _loadBildirimler();
        },
        backgroundColor: deepGreen.withOpacity(0.05),
        selectedColor: deepGreen,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : deepGreen,
          fontWeight: FontWeight.bold,
        ),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? deepGreen : deepGreen.withOpacity(0.2),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'Henüz bildirim yok';
    String subtitle = 'Bu kategoride bildirim bulunmuyor';
    
    if (_selectedFilter == 'istekler') {
      message = 'Yeni istek yok';
      subtitle = 'Kullanıcılardan gelen istekler burada görünecek';
    } else if (_selectedFilter == 'onaylananlar') {
      message = 'Henüz onaylanan yok';
      subtitle = 'Onayladığın kafeler burada görünecek';
    } else if (_selectedFilter == 'reddedilenler') {
      message = 'Henüz reddedilen yok';
      subtitle = 'Reddettiğin istekler burada görünecek';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: deepGreen.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: deepGreen.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBildirimCard(Map<String, dynamic> bildirim) {
    final kafeAdi = bildirim['kafe_adi'] ?? 'İsimsiz Kafe';
    final notlar = bildirim['notlar'] ?? '';
    final lat = bildirim['latitude'];
    final lng = bildirim['longitude'];
    final username = bildirim['user_info']?['username'] ?? 'Bilinmiyor';
    final createdAt = DateTime.parse(bildirim['created_at']);
    final durum = bildirim['durum'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      shadowColor: deepGreen.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              vanilla.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Durum
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [deepGreen, midGreen],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: deepGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_cafe,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kafeAdi,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: deepGreen,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: midGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              username,
                              style: TextStyle(
                                fontSize: 13,
                                color: midGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildDurumBadge(durum),
                ],
              ),
              const SizedBox(height: 16),

              // Konum Kartı
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: deepGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: deepGreen.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: deepGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: deepGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koordinatlar',
                            style: TextStyle(
                              fontSize: 11,
                              color: deepGreen.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: deepGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.map, size: 20),
                        color: Colors.blue,
                        onPressed: () {
                          // Haritada göster
                          _showOnMap(lat, lng, kafeAdi);
                        },
                        tooltip: 'Haritada Göster',
                      ),
                    ),
                  ],
                ),
              ),

              // Notlar
              if (notlar.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt_outlined, color: Colors.amber[700], size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notlar,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Tarih
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: deepGreen.withOpacity(0.5)),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: deepGreen.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Aksiyon Butonları
              Row(
                children: [
                  // İSTEKLER sekmesinde (beklemede veya inceleniyor)
                  if (durum == 'beklemede') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateDurum(bildirim['id'], 'inceleniyor'),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('İncele'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                  if (durum == 'inceleniyor') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportSingleToJSON(bildirim),
                        icon: const Icon(Icons.code, size: 18),
                        label: const Text('Python\'a Gönder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateDurum(bildirim['id'], 'eklendi'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Onayla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateDurum(bildirim['id'], 'reddedildi'),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Reddet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // ONAYLANANLAR sekmesinde
                  if (durum == 'eklendi') ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Veritabanına Eklendi',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteBildirim(bildirim['id'], kafeAdi),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: 'Sil',
                    ),
                  ],
                  
                  // REDDEDİLENLER sekmesinde
                  if (durum == 'reddedildi') ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Reddedildi',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteBildirim(bildirim['id'], kafeAdi),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: 'Sil',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurumBadge(String durum) {
    Color color;
    String emoji;
    
    switch (durum) {
      case 'beklemede':
        color = Colors.orange;
        emoji = '⏳';
        break;
      case 'inceleniyor':
        color = Colors.blue;
        emoji = '🔍';
        break;
      case 'eklendi':
        color = Colors.green;
        emoji = '✅';
        break;
      case 'reddedildi':
        color = Colors.red;
        emoji = '❌';
        break;
      default:
        color = Colors.grey;
        emoji = '❓';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$emoji ${durum[0].toUpperCase()}${durum.substring(1)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Bugün ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
