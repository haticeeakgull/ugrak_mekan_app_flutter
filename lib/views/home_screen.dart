import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'package:ugrak_mekan_app/widgets/search_overlay.dart';
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
  bool _isPanelOpen = false; // panel durumunu home_screen'de de takip ediyoruz
  String? _currentUserEmail;
  List<String> _semtler = [];
  List<String> _vibeler = [];

  final GlobalKey _searchKey = GlobalKey();
  double _searchBarHeight = 166; // header (~110) + search bar (~56)

  // --- YENİ RENK PALETİ TANIMLARI ---
  final Color deepGreen = const Color(
    0xFF346739,
  ); // Yazılar, İkonlar, Ana Butonlar
  final Color midGreen = const Color(0xFF79AE6F); // Vurgu ve Alt Başlıklar
  final Color lightGreen = const Color(0xFF9FCB98); // Yumuşak geçişler
  final Color vanilla = const Color(0xFFF2EDC2); // Arka Plan Dokunuşları

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _filtreleriYukle();
    _currentUserEmail = supabase.auth.currentUser?.email;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
      // Search bar yüksekliğini ölç
      final ctx = _searchKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && mounted) {
          setState(() => _searchBarHeight = box.size.height);
        }
      }
    });
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleDeepLink(initialLink);
    _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.queryParameters.containsKey('koleksiyonId')) {
      final String? collectionId = uri.queryParameters['koleksiyonId'];
      if (collectionId != null && mounted) {
        // Koleksiyon sahibini öğrenmek için koleksiyonu çek
        try {
          final collection = await supabase
              .from('koleksiyonlar')
              .select('user_id, isim')
              .eq('id', collectionId)
              .maybeSingle();
          
          if (mounted && collection != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CollectionDetailScreen(
                  collectionId: collectionId,
                  collectionName: collection['isim'] ?? "Paylaşılan Koleksiyon",
                  ownerId: collection['user_id']?.toString(),
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Koleksiyon bilgisi alınamadı: $e');
        }
      }
    }
  }

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
      final ilceSonuc = await _supabaseService.fetchIlceler();
      final vibeSonuc = await _supabaseService.fetchVibeEtiketleri();
      setState(() {
        _semtler = ilceSonuc;
        _vibeler = vibeSonuc;
      });
    } catch (e) {}
  }

  void _startSearch(
    String? il,
    List<String> ilceler,
    List<String> vibeler,
    String dogalDil,
    double? userLat,
    double? userLng,
  ) async {
    setState(() => _isLoading = true);
    
    try {
      List<Cafe> results;
      
      // DIRECT: prefix'i varsa normal arama, yoksa AI arama
      if (dogalDil.startsWith('DIRECT:')) {
        // Normal arama - Ada göre
        final searchQuery = dogalDil.replaceFirst('DIRECT:', '');
        debugPrint('🔍 Normal arama yapılıyor: "$searchQuery"');
        
        results = await _apiService.searchCafesByName(
          searchQuery.isEmpty ? 'kafe' : searchQuery,
          il: il,
          semt: ilceler.isNotEmpty ? ilceler.first : null,
          vibe: vibeler.isNotEmpty ? vibeler.first : null,
          userLat: userLat,
          userLng: userLng,
        );
      } else if (dogalDil.isNotEmpty) {
        // AI arama - Semantik anlam + yorumlar
        debugPrint('🤖 AI arama yapılıyor: "$dogalDil"');
        
        results = await _apiService.searchCafes(
          dogalDil,
          il: il,
          semt: ilceler.isNotEmpty ? ilceler.first : null,
          vibe: vibeler.isNotEmpty ? vibeler.first : null,
          userLat: userLat,
          userLng: userLng,
        );
      } else {
        // Sadece filtrelerle arama (AI değil)
        debugPrint('🔍 Filtre bazlı arama yapılıyor');
        
        results = await _apiService.searchCafesByName(
          'kafe',
          il: il,
          semt: ilceler.isNotEmpty ? ilceler.first : null,
          vibe: vibeler.isNotEmpty ? vibeler.first : null,
          userLat: userLat,
          userLng: userLng,
        );
      }
      
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      final isTimeout = e.toString().contains('57014') ||
          e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTimeout
                ? 'Sunucu yavaş yanıt verdi, tekrar deneyin.'
                : 'Arama başarısız oldu.',
          ),
          backgroundColor: deepGreen,
          action: isTimeout
              ? SnackBarAction(
                  label: 'Tekrar Dene',
                  textColor: Colors.white,
                  onPressed: () => _startSearch(il, ilceler, vibeler, dogalDil, userLat, userLng),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: null,
      // Klavye açıldığında içeriğin kaymasını ve taşma hatasını (overflow) engeller
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. SONUÇ LİSTESİ — search bar'ın altından başlar
            Positioned(
              top: _isPanelOpen ? 0 : _searchBarHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: _isPanelOpen
                  ? const SizedBox.shrink()
                  : _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: deepGreen),
                    )
                  : _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          CafeCard(cafe: _results[index]),
                    ),
            ),

            // 2. ARAMA PANELİ — üstte overlay
            Align(
              alignment: Alignment.topCenter,
              child: ModernSearchExperience(
                key: _searchKey,
                vibeler: _vibeler,
                semtler: _semtler,
                onSearch: _startSearch,
                onPanelToggle: (isOpen) {
                  setState(() => _isPanelOpen = isOpen);
                  // Panel kapandığında yüksekliği ölç
                  if (!isOpen) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = _searchKey.currentContext;
                      if (ctx != null) {
                        final box = ctx.findRenderObject() as RenderBox?;
                        if (box != null && mounted) {
                          setState(() => _searchBarHeight = box.size.height);
                        }
                      }
                    });
                  }
                },
                currentUserEmail: _currentUserEmail,
                onLogout: _showLogoutDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: vanilla.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.coffee_outlined, // Temaya uygun doğa ikonu
              size: 50,
              color: deepGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Keşfedilmeyi Bekleyen Yerler',
            style: TextStyle(
              color: deepGreen,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Arama butonuna basarak sana en uygun mekanları bulabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: midGreen,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: vanilla,
        title: Text(
          'Oturumu Kapat',
          style: TextStyle(fontWeight: FontWeight.w900, color: deepGreen),
        ),
        content: Text(
          'Uygulamadan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(
            color: deepGreen.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Geri Dön',
              style: TextStyle(color: midGreen, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: deepGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              supabase.auth.signOut();
            },
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
