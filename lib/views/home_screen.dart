import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart'; // Yeni ekledik
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
  final SupabaseService _supabaseService = SupabaseService(); // Servis tanımı

  List<Cafe> _results = [];
  bool _isLoading = false;

  // --- Filtre Değişkenleri ---
  String? _secilenSemt;
  String? _secilenVibe;
  List<String> _semtler = [];
  List<String> _vibeler = [];

  @override
  void initState() {
    super.initState();
    _filtreleriYukle(); // Sayfa açıldığında veritabanından listeleri çek
  }

  // Supabase'deki View'lardan verileri çeken fonksiyon
  Future<void> _filtreleriYukle() async {
    print("Semtler yükleniyor...");
    try {
      final semtSonuc = await _supabaseService.fetchSemtler();
      final vibeSonuc = await _supabaseService.fetchVibeEtiketleri();

      // Veriler geldiğinde ekranı tazelemek için mutlaka setState kullanmalıyız
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
    print("State güncellendi, semt sayısı: ${_semtler.length}");

    try {
      // ApiService içindeki searchCafes metoduna filtreleri de gönderiyoruz
      // Not: ApiService içindeki metodun parametrelerini buna göre güncellemeyi unutma!
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
        title: const Text(
          'Uğrak Mekan ☕',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. Arama Kutusu Alanı
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 2. Filtreleme Alanı (Dropdownlar)
            Row(
              children: [
                // Semt Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                ),
                const SizedBox(width: 10),
                // Vibe Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Sonuç Listesi Alanı
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepOrange,
                      ),
                    )
                  : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.coffee_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Henüz sonuç yok. Haydi ara!',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        return CafeCard(cafe: _results[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
