import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'package:ugrak_mekan_app/widgets/search_overlay.dart'; // Yeni import
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
  final ApiService _apiService = ApiService();
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient supabase = Supabase.instance.client;
  final AppLinks _appLinks = AppLinks();

  List<Cafe> _results = [];
  bool _isLoading = false;
  String? _currentUserEmail;
  List<String> _semtler = [];
  List<String> _vibeler = [];

  // Arama durumu bilgisi
  String _activeSearchLabel = "Nereye gidiyorsun?";

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _filtreleriYukle();
    _currentUserEmail = supabase.auth.currentUser?.email;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfile());
  }

  // --- BOZULMAYAN KOLEKSİYON MANTIĞI (Deep Link) ---
  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleDeepLink(initialLink);
    _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  void _handleDeepLink(Uri uri) {
    if (uri.queryParameters.containsKey('koleksiyonId')) {
      final String? collectionId = uri.queryParameters['koleksiyonId'];
      if (collectionId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionDetailScreen(
              collectionId: collectionId,
              collectionName: "Paylaşılan Koleksiyon",
            ),
          ),
        );
      }
    }
  }

  // --- SERVİS VE PROFİL İŞLEMLERİ ---
  Future<void> _checkProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await supabase
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    if (data == null || data['username'] == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/complete-profile');
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
      print("Filtre hatası: $e");
    }
  }

  // --- YENİ HİBRİT ARAMA TETİKLEYİCİ ---
  void _startSearch(
    String? il,
    List<String> ilceler,
    List<String> vibeler,
    String dogalDil,
  ) async {
    setState(() {
      _isLoading = true;
      _activeSearchLabel = il ?? "Tüm Şehirler";
    });

    try {
      final results = await _apiService.searchCafes(
        dogalDil,
        il: il,
        vibe: vibeler.isNotEmpty
            ? vibeler.first
            : null, // Mevcut API'ne göre güncellendi
      );
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Arama başarısız oldu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildPrimeSearchBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  )
                : _results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        CafeCard(cafe: _results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Column(
        children: [
          const Text(
            'Uğrak Mekan ☕',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          if (_currentUserEmail != null)
            Text(
              _currentUserEmail!,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _showLogoutDialog,
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildPrimeSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "Search",
          pageBuilder: (_, __, ___) => SearchOverlay(
            vibeler: _vibeler,
            semtler: _semtler,
            onSearch: _startSearch,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.deepOrange),
              const SizedBox(width: 12),
              Text(
                _activeSearchLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.tune, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Sana uygun mekanı bulalım!',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- ÇIKIŞ DİALOGU (AYNI KALDI) ---
  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Çıkış Yap'),
        content: const Text('Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              supabase.auth.signOut();
            },
            child: const Text('Çıkış', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
