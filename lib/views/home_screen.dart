import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Çıkış için ekledik
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import '../models/cafe_model.dart';
import '../widgets/cafe_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient supabase = Supabase.instance.client; // Supabase instance

  List<Cafe> _results = [];
  bool _isLoading = false;
  String? _currentUserEmail;

  // --- Filtre Değişkenleri ---
  String? _secilenSemt;
  String? _secilenVibe;
  List<String> _semtler = [];
  List<String> _vibeler = [];

  @override
  @override
  void initState() {
    super.initState();
    _filtreleriYukle();
    _currentUserEmail = supabase.auth.currentUser?.email;

    // Widget ağacı oluştuktan hemen sonra kontrolü başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
    });
  }

  // Fonksiyonu initState dışına aldık ki daha okunaklı olsun
  Future<void> _checkProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // maybeSingle() hata almanı engeller, veri yoksa null döner
      final data = await supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();

      // Eğer username sütunu boşsa veya satır hiç yoksa yönlendir
      if (data == null || data['username'] == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/complete-profile');
        }
      }
    } catch (e) {
      print("Profil kontrol hatası: $e");
    }
  }

  // Çıkış Yapma Fonksiyonu
  Future<void> _handleSignOut() async {
    try {
      await supabase.auth.signOut();
      // AuthWrapper sayesinde otomatik Login ekranına dönecektir.
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Çıkış yapılamadı: $e')));
    }
  }

  Future<void> _filtreleriYukle() async {
    try {
      final semtSonuc = await _supabaseService.fetchSemtler();
      final vibeSonuc = await _supabaseService.fetchVibeEtiketleri();

      setState(() {
        _semtler = semtSonuc;
        _vibeler = vibeSonuc;
      });
    } catch (e) {
      print("Filtre yükleme hatası: $e");
    }
  }

  void _handleSearch() async {
    if (_searchController.text.isEmpty &&
        _secilenSemt == null &&
        _secilenVibe == null)
      return;

    setState(() => _isLoading = true);

    try {
      final results = await _apiService.searchCafes(
        _searchController.text,
        semt: _secilenSemt,
        vibe: _secilenVibe,
      );

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arama sırasında bir hata oluştu!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Uğrak Mekan ☕',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (_currentUserEmail != null)
              Text(
                _currentUserEmail!,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // SOL ÜSTE PROFİL İKONU (İleride Profil Sayfasına Gider)
        leading: IconButton(
          icon: const Icon(Icons.person_pin, color: Colors.deepOrange),
          onPressed: () {
            Navigator.pushNamed(context, '/complete-profile');
          },
        ),
        // SAĞ ÜSTE ÇIKIŞ BUTONU
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Arama Kutusu
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Nasıl bir mekan arıyorsun?',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Dropdown Filtreleri
            Row(
              children: [
                _buildFilterContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _secilenSemt,
                      hint: const Text("Semt Seç"),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Tüm Semtler"),
                        ),
                        ..._semtler.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (val) => setState(() => _secilenSemt = val),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFilterContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _secilenVibe,
                      hint: const Text("Tarz Seç"),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Tüm Tarzlar"),
                        ),
                        ..._vibeler.map(
                          (v) => DropdownMenuItem(value: v, child: Text(v)),
                        ),
                      ],
                      onChanged: (val) => setState(() => _secilenVibe = val),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sonuçlar
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepOrange,
                      ),
                    )
                  : _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          CafeCard(cafe: _results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Yardımcı Widget: Filtre Kutusu
  Widget _buildFilterContainer({required Widget child}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: child,
      ),
    );
  }

  // Yardımcı Widget: Boş Liste Ekranı
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 10),
          const Text(
            'Henüz sonuç yok. Haydi ara!',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Çıkış Onay Diyaloğu
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Kullanıcı dışarı tıklayarak kapatamasın
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Çıkış Yap'),
          content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(), // Diyaloğu kapat
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Çıkış Yap'),
              onPressed: () {
                Navigator.of(context).pop(); // Diyaloğu kapat
                _handleSignOut(); // Asıl çıkış işlemini çağır
              },
            ),
          ],
        );
      },
    );
  }
}
