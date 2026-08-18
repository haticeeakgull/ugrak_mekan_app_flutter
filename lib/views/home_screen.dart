import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:ugrak_mekan_app/views/collection_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'package:ugrak_mekan_app/widgets/search_overlay.dart';
import 'package:ugrak_mekan_app/widgets/native_ad_widget.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import '../models/cafe_model.dart';
import '../widgets/cafe_card.dart';
import '../utils/error_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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

  // Animation Controllers
  late AnimationController _steamController;
  late AnimationController _cupRotateController;
  late AnimationController _bounceController;
  late Animation<double> _steamOpacity;
  late Animation<double> _cupRotate;
  late Animation<double> _bounceAnimation;

  // --- YENİ RENK PALETİ TANIMLARI ---
  final Color deepGreen = const Color(
    0xFF346739,
  ); // Yazılar, İkonlar, Ana Butonlar
  final Color midGreen = const Color(0xFF79AE6F); // Vurgu ve Alt Başlıklar
  final Color lightGreen = const Color(0xFF9FCB98); // Yumuşak geçişler
  final Color vanilla = const Color(0xFFFAF8F3); // Arka Plan Dokunuşları

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _filtreleriYukle();
    _currentUserEmail = supabase.auth.currentUser?.email;
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
    });
  }

  void _initAnimations() {
    // Steam animation - duman için
    _steamController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _steamOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _steamController, curve: Curves.easeInOut),
    );

    // Cup rotation - hafif dönme
    _cupRotateController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _cupRotate = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _cupRotateController, curve: Curves.easeInOut),
    );

    // Bounce animation - location icon için
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _steamController.dispose();
    _cupRotateController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleDeepLink(initialLink);
    _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('🔗 Gelen Deep Link: $uri');

    String? collectionId;

    // 1. Durum: ID Path içinden geliyorsa (Örn: /ugrak-web/koleksiyon/XYZ123 veya /koleksiyon/XYZ123)
    final segments = uri.pathSegments;
    if (segments.contains('koleksiyon')) {
      final index = segments.indexOf('koleksiyon');
      if (index + 1 < segments.length) {
        collectionId = segments[index + 1];
      }
    }

    // 2. Durum: ID Query parametresinden geliyorsa (Örn: ?koleksiyonId=XYZ123)
    if (collectionId == null &&
        uri.queryParameters.containsKey('koleksiyonId')) {
      collectionId = uri.queryParameters['koleksiyonId'];
    }

    // Eğer Koleksiyon ID bulunduysa ekranı aç
    if (collectionId != null && collectionId.isNotEmpty && mounted) {
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
                collectionId: collectionId!,
                collectionName: collection['isim'] ?? "Paylaşılan Koleksiyon",
                ownerId: collection['user_id']?.toString(),
              ),
            ),
          );
        }
      } catch (e) {
        ErrorHandler.logError('Deep link koleksiyon yükleme', e);
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
          vibes: vibeler, // Artık liste olarak gönderiyoruz
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
          vibes: vibeler, // Artık liste olarak gönderiyoruz
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
          vibes: vibeler,
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

      // Kullanıcı dostu hata mesajı al
      final errorConfig = ErrorHandler.getErrorSnackbarConfig(e);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorConfig['message']),
          backgroundColor: deepGreen,
          action: errorConfig['showRetry']
              ? SnackBarAction(
                  label: 'Tekrar Dene',
                  textColor: Colors.white,
                  onPressed: () => _startSearch(
                      il, ilceler, vibeler, dogalDil, userLat, userLng),
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
        child: _isPanelOpen
            ? Stack(
                children: [
                  // Panel açıkken search overlay tüm ekranı kaplar
                  ModernSearchExperience(
                    key: _searchKey,
                    vibeler: _vibeler,
                    semtler: _semtler,
                    onSearch: _startSearch,
                    onPanelToggle: (isOpen) {
                      setState(() => _isPanelOpen = isOpen);
                    },
                    currentUserEmail: _currentUserEmail,
                    onLogout: _showLogoutDialog,
                  ),
                ],
              )
            : Column(
                children: [
                  // 1. ARAMA PANELİ — üstte sabit
                  ModernSearchExperience(
                    key: _searchKey,
                    vibeler: _vibeler,
                    semtler: _semtler,
                    onSearch: _startSearch,
                    onPanelToggle: (isOpen) {
                      setState(() => _isPanelOpen = isOpen);
                    },
                    currentUserEmail: _currentUserEmail,
                    onLogout: _showLogoutDialog,
                  ),

                  // 2. SONUÇ LİSTESİ — search bar'ın hemen altında
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(color: deepGreen),
                          )
                        : _results.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 80),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _results.length + (_results.length ~/ 4),
                                itemBuilder: (context, index) {
                                  // Her 4. cafe kartından sonra native reklam göster
                                  if (index != 0 && index % 5 == 0) {
                                    return const Padding(
                                      padding: EdgeInsets.zero,
                                      child: NativeAdWidget(),
                                    );
                                  }
                                  
                                  // Reklam sayısını çıkararak gerçek cafe index'ini bul
                                  final cafeIndex = index - (index ~/ 5);
                                  if (cafeIndex >= _results.length) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  return CafeCard(cafe: _results[cafeIndex]);
                                },
                              ),
                  ),
                ],
              ),
            ),
      );
  
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Animated Coffee Cup Hero - Clean Design
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deepGreen.withOpacity(0.12),
                    midGreen.withOpacity(0.08),
                    lightGreen.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: deepGreen.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 10,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Main Coffee Cup with rotation
                  AnimatedBuilder(
                    animation: _cupRotate,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _cupRotate.value,
                        child: Icon(
                          Icons.coffee_rounded,
                          size: 90,
                          color: deepGreen,
                        ),
                      );
                    },
                  ),
                  // Steam effects - 3 animated wisps closer to cup
                  Positioned(
                    top: 35,
                    left: 70,
                    child: AnimatedBuilder(
                      animation: _steamOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _steamOpacity.value * 0.6,
                          child: Transform.translate(
                            offset: Offset(
                              (_steamOpacity.value - 0.5) * 6,
                              -_steamOpacity.value * 25,
                            ),
                            child: Transform.scale(
                              scale: 0.5 + _steamOpacity.value * 0.5,
                              child: Container(
                                width: 10,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      deepGreen.withOpacity(0.5),
                                      deepGreen.withOpacity(0.0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 38,
                    left: 85,
                    child: AnimatedBuilder(
                      animation: _steamOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: (1 - _steamOpacity.value) * 0.7,
                          child: Transform.translate(
                            offset: Offset(
                              -(_steamOpacity.value - 0.5) * 8,
                              -(1 - _steamOpacity.value) * 30,
                            ),
                            child: Transform.scale(
                              scale: 0.6 + (1 - _steamOpacity.value) * 0.4,
                              child: Container(
                                width: 12,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      midGreen.withOpacity(0.6),
                                      midGreen.withOpacity(0.0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 32,
                    left: 100,
                    child: AnimatedBuilder(
                      animation: _steamOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _steamOpacity.value * 0.5,
                          child: Transform.translate(
                            offset: Offset(
                              (_steamOpacity.value - 0.5) * 5,
                              -_steamOpacity.value * 22,
                            ),
                            child: Transform.scale(
                              scale: 0.4 + _steamOpacity.value * 0.6,
                              child: Container(
                                width: 9,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      lightGreen.withOpacity(0.7),
                                      lightGreen.withOpacity(0.0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bouncing Location Icon - Right side
                  Positioned(
                    right: 5,
                    top: 65,
                    child: AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _bounceAnimation.value),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [deepGreen, midGreen],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: deepGreen.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bouncing Search Icon - Left side
                  Positioned(
                    left: 5,
                    top: 65,
                    child: AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, -_bounceAnimation.value * 0.8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [midGreen, lightGreen],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: midGreen.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Title with gradient effect
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  deepGreen,
                  midGreen,
                ],
              ).createShader(bounds),
              child: const Text(
                'Keşfedilmeyi Bekleyen Yerler',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Subtitle
            Text(
              'Arama butonuna basarak sana en uygun mekanları keşfedebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: deepGreen.withOpacity(0.7),
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 40),
            // Feature Cards
            _buildFeatureCard(
              icon: Icons.search_rounded,
              title: 'Akıllı Arama',
              description: 'İstediğin mekanı hızlıca bul',
              gradient: [deepGreen, midGreen],
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Önerileri',
              description: 'Yapay zeka ile kişiselleştirilmiş sonuçlar',
              gradient: [midGreen, lightGreen],
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              icon: Icons.filter_list_rounded,
              title: 'Gelişmiş Filtreler',
              description: 'Şehir, ilçe ve vibe seçenekleri',
              gradient: [lightGreen, midGreen.withOpacity(0.7)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withOpacity(0.08),
            gradient[1].withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: deepGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: deepGreen.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
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
