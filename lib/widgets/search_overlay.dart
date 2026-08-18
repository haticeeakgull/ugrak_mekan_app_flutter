import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../utils/error_handler.dart';

class ModernSearchExperience extends StatefulWidget {
  final List<String> vibeler;
  final List<String> semtler;
  // il, ilceler, vibeler, dogalDil, userLat, userLng
  final Function(String?, List<String>, List<String>, String, double?, double?) onSearch;
  final ValueChanged<bool>? onPanelToggle;
  final String? currentUserEmail;
  final VoidCallback? onLogout;

  const ModernSearchExperience({
    super.key,
    required this.vibeler,
    required this.semtler,
    required this.onSearch,
    this.onPanelToggle,
    this.currentUserEmail,
    this.onLogout,
  });

  @override
  State<ModernSearchExperience> createState() => _ModernSearchExperienceState();
}

class _ModernSearchExperienceState extends State<ModernSearchExperience>
    with TickerProviderStateMixin {
  String? selectedCity;
  String? selectedDistrict;
  List<String> selectedVibes = [];
  String aiText = "";
  bool isPanelOpen = false;
  int? expandedIndex;

  // Konum bazlı arama için
  bool _isNearby = false;
  bool _isLoadingLocation = false;
  String? _nearbyCity;
  double? _userLat;
  double? _userLng;

  // Şehre göre dinamik ilçe listesi
  List<String> _filteredIlceler = [];
  bool _isLoadingIlceler = false;

  // Dinamik şehir listesi
  List<String> _sehirler = [];
  bool _isLoadingSehirler = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SupabaseService _supabaseService = SupabaseService();

  // Animation Controllers
  late AnimationController _steamController;
  late AnimationController _bounceController;
  late Animation<double> _steamOpacity;
  late Animation<double> _bounceAnimation;

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color lightGreen = const Color(0xFF9FCB98);
  final Color vanilla = const Color(0xFFFAF8F3);

  @override
  void initState() {
    super.initState();
    _loadSehirler();
    _initAnimations();
  }

  void _initAnimations() {
    // Steam animation - duman için
    _steamController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _steamOpacity = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _steamController, curve: Curves.easeInOut),
    );

    // Bounce animation - location icon için
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _steamController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  // Database'den şehir listesini yükle
  Future<void> _loadSehirler() async {
    setState(() => _isLoadingSehirler = true);
    try {
      final sehirler = await _supabaseService.fetchSehirler();
      if (mounted) {
        setState(() {
          _sehirler = sehirler;
          _isLoadingSehirler = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sehirler = ['İstanbul', 'Ankara', 'İzmir']; // Fallback
          _isLoadingSehirler = false;
        });
      }
    }
  }

  void _triggerSearch({bool useAI = false}) {
    final String? ilParam = _isNearby ? _nearbyCity : selectedCity;
    final String searchText = _searchController.text.trim();
    
    widget.onSearch(
      ilParam,
      selectedDistrict != null ? [selectedDistrict!] : [],
      selectedVibes,
      useAI ? searchText : 'DIRECT:$searchText',
      _isNearby ? _userLat : null,
      _isNearby ? _userLng : null,
    );
  }
  
  void _applyFilters() {
    // Filtreleri kaydet ve paneli kapat
    setState(() => isPanelOpen = false);
    widget.onPanelToggle?.call(false);
    
    // Mevcut arama metni var mı kontrol et
    final String searchText = _searchController.text.trim();
    
    // Eğer arama metni varsa veya konum bazlı arama yapılıyorsa, direkt aramayı tetikle
    if (searchText.isNotEmpty || _isNearby) {
      _triggerSearch(useAI: searchText.isNotEmpty);
      _showSnack('Filtreler uygulanarak arama yapılıyor...');
    } else {
      // Arama metni yoksa sadece filtreleri uygula
      _showSnack('Filtreler uygulandı. Arama yapmak için metin girin.');
    }
  }

  Future<void> _onCitySelected(String city) async {
    if (city == '📍 Konumum') {
      await _handleNearbySelected();
      return;
    }

    setState(() {
      selectedCity = city;
      selectedDistrict = null;
      _isNearby = false;
      _filteredIlceler = [];
      _isLoadingIlceler = true;
    });

    try {
      final ilceler = await _supabaseService.fetchIlcelerByIl(city);
      if (mounted) {
        setState(() {
          _filteredIlceler = ilceler;
          _isLoadingIlceler = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('İlçe yükleme', e);
      if (mounted) setState(() => _isLoadingIlceler = false);
    }
    // Arama yapma - sadece filtre seçimi
  }

  Future<void> _handleNearbySelected() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Konum servisi kapalı, lütfen açın.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Konum izni gerekli.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Koordinattan en yakın şehri bul
      final nearestCity = _findNearestCity(position.latitude, position.longitude);

      setState(() {
        _isNearby = true;
        _nearbyCity = nearestCity;
        _userLat = position.latitude;
        _userLng = position.longitude;
        selectedCity = null;
        selectedDistrict = null;
        _filteredIlceler = [];
        _isLoadingLocation = false;
      });
      
      // Otomatik olarak yakındaki kafeleri göster
      _triggerNearbySearch();
    } catch (e) {
      ErrorHandler.logError('Konum alma', e);
      _showSnack(ErrorHandler.getUserFriendlyMessage(e));
      setState(() => _isLoadingLocation = false);
    }
  }

  /// Konuma göre otomatik arama
  void _triggerNearbySearch() {
    final String searchText = _searchController.text.trim();
    widget.onSearch(
      _nearbyCity,
      [],
      selectedVibes,
      searchText.isEmpty ? '' : 'DIRECT:$searchText',
      _userLat,
      _userLng,
    );
  }

  /// Koordinata en yakın desteklenen şehri döner
  String? _findNearestCity(double lat, double lng) {
    // Türkiye'nin büyük şehirlerinin koordinatları
    final cities = {
      'İstanbul': (41.0082, 28.9784),
      'Ankara': (39.9334, 32.8597),
      'İzmir': (38.4192, 27.1287),
      'Bursa': (40.1885, 29.0610),
      'Antalya': (36.8969, 30.7133),
      'Adana': (37.0000, 35.3213),
      'Konya': (37.8746, 32.4932),
      'Gaziantep': (37.0662, 37.3833),
      'Mersin': (36.8000, 34.6333),
      'Kayseri': (38.7312, 35.4787),
      'Diyarbakır': (37.9144, 40.2306),
      'Eskişehir': (39.7767, 30.5206),
      'Samsun': (41.2867, 36.3300),
      'Denizli': (37.7765, 29.0864),
      'Şanlıurfa': (37.1591, 38.7969),
      'Trabzon': (41.0015, 39.7178),
      'Malatya': (38.3554, 38.3095),
      'Kahramanmaraş': (37.5858, 36.9371),
      'Erzurum': (39.9000, 41.2700),
      'Van': (38.4891, 43.4089),
      'Elazığ': (38.6810, 39.2264),
      'Kocaeli': (40.8533, 29.8815),
      'Balıkesir': (39.6484, 27.8826),
      'Sakarya': (40.7569, 30.4093),
      'Manisa': (38.6191, 27.4289),
      'Aydın': (37.8560, 27.8416),
      'Tekirdağ': (40.9833, 27.5167),
      'Muğla': (37.2153, 28.3636),
      'Kütahya': (39.4242, 29.9833),
      'Sivas': (39.7477, 37.0179),
    };

    String? nearest;
    double minDist = double.infinity;

    for (final entry in cities.entries) {
      final dLat = lat - entry.value.$1;
      final dLng = lng - entry.value.$2;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < minDist) {
        minDist = dist;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: deepGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPremiumHeader(),
            const SizedBox(height: 12),
            _buildHeroSearchBar(),
            if (isPanelOpen)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: vanilla.withOpacity(0.93),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: midGreen.withOpacity(0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: deepGreen.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildExpandableCard(
                                0,
                                "Şehir Seç",
                                _isNearby
                                    ? "📍 Konumum"
                                    : (selectedCity ?? "Şehir seçilmedi"),
                                Icons.location_on_outlined,
                                _buildCityList(),
                              ),
                              if (selectedCity != null && !_isNearby)
                                _buildExpandableCard(
                                  1,
                                  "İlçe Seç",
                                  selectedDistrict ?? "Tüm ilçeler",
                                  Icons.map_outlined,
                                  _buildDistrictScroll(),
                                ),
                              _buildExpandableCard(
                                2,
                                "Vibe Seçenekleri",
                                selectedVibes.isEmpty
                                    ? "Etiket seçilmedi"
                                    : "${selectedVibes.length} etiket seçildi",
                                Icons.eco_outlined,
                                _buildVibeChips(),
                              ),
                              _buildActionRow(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCard(
    int index,
    String title,
    String subtitle,
    IconData icon,
    Widget content,
  ) {
    bool isExpanded = expandedIndex == index;
    bool hasSelection =
        !subtitle.contains("seçilmedi") &&
        !subtitle.contains("Tüm") &&
        !subtitle.contains("tarif et");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: isExpanded
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.95),
                    vanilla.withOpacity(0.8),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.25),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded
                ? deepGreen.withOpacity(0.4)
                : midGreen.withOpacity(0.25),
            width: isExpanded ? 2 : 1.5,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: deepGreen.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: lightGreen.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: deepGreen.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    setState(() => expandedIndex = isExpanded ? null : index),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Icon with enhanced styling
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isExpanded
                                ? [deepGreen, midGreen]
                                : [
                                    deepGreen.withOpacity(0.15),
                                    midGreen.withOpacity(0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isExpanded
                              ? [
                                  BoxShadow(
                                    color: deepGreen.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          icon,
                          color: isExpanded ? Colors.white : deepGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: deepGreen.withOpacity(0.7),
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 15,
                                color: hasSelection
                                    ? deepGreen
                                    : deepGreen.withOpacity(0.55),
                                fontWeight: hasSelection
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow icon with animation
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? deepGreen.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: deepGreen,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: content,
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityList() {
    if (_isLoadingLocation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  deepGreen.withOpacity(0.1),
                  midGreen.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: deepGreen,
                    valueColor: AlwaysStoppedAnimation<Color>(midGreen),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Konum alınıyor...',
                  style: TextStyle(
                    color: deepGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingSehirler) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  deepGreen.withOpacity(0.1),
                  midGreen.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: deepGreen,
                    valueColor: AlwaysStoppedAnimation<Color>(midGreen),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Şehirler yükleniyor...',
                  style: TextStyle(
                    color: deepGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_sehirler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Şehir listesi yüklenemedi.',
          style: TextStyle(
            color: deepGreen.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ['📍 Konumum', ..._sehirler].map((c) {
        final isNearbyChip = c == '📍 Konumum';
        final isSel = isNearbyChip ? _isNearby : selectedCity == c;
        return Container(
          decoration: BoxDecoration(
            gradient: isSel
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [deepGreen, midGreen],
                  )
                : null,
            color: isSel ? null : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel
                  ? deepGreen.withOpacity(0.3)
                  : deepGreen.withOpacity(0.2),
              width: isSel ? 2 : 1.5,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: deepGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isSel) {
                  setState(() {
                    if (isNearbyChip) {
                      _isNearby = false;
                      _nearbyCity = null;
                      _userLat = null;
                      _userLng = null;
                    } else {
                      selectedCity = null;
                      selectedDistrict = null;
                      _filteredIlceler = [];
                    }
                  });
                } else {
                  _onCitySelected(c);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNearbyChip)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: isSel ? Colors.white : deepGreen,
                        ),
                      ),
                    Text(
                      isNearbyChip ? 'Konumum' : c,
                      style: TextStyle(
                        color: isSel ? Colors.white : deepGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDistrictScroll() {
    if (_isLoadingIlceler) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: deepGreen,
            valueColor: AlwaysStoppedAnimation<Color>(midGreen),
          ),
        ),
      );
    }

    if (_filteredIlceler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Bu şehir için ilçe bulunamadı.',
          style: TextStyle(
            color: deepGreen.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _filteredIlceler.map((s) {
        bool isSel = selectedDistrict == s;
        return Container(
          decoration: BoxDecoration(
            gradient: isSel
                ? LinearGradient(
                    colors: [midGreen, lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSel ? null : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel
                  ? midGreen.withOpacity(0.4)
                  : deepGreen.withOpacity(0.2),
              width: isSel ? 2 : 1.5,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: midGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => selectedDistrict = isSel ? null : s);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: isSel ? Colors.white : deepGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVibeChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: widget.vibeler.map((v) {
        bool isSel = selectedVibes.contains(v);
        return Container(
          decoration: BoxDecoration(
            gradient: isSel
                ? LinearGradient(
                    colors: [
                      midGreen,
                      lightGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.3),
                    ],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel
                  ? midGreen.withOpacity(0.4)
                  : deepGreen.withOpacity(0.2),
              width: isSel ? 2 : 1.5,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: midGreen.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSel) {
                    selectedVibes.remove(v);
                  } else {
                    selectedVibes.add(v);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSel)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    Text(
                      v,
                      style: TextStyle(
                        color: isSel ? Colors.white : deepGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Reset Button - Enhanced
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.6),
                    Colors.white.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: deepGreen.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: deepGreen.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedCity = null;
                      selectedDistrict = null;
                      selectedVibes.clear();
                      expandedIndex = null;
                      _isNearby = false;
                      _nearbyCity = null;
                      _userLat = null;
                      _userLng = null;
                      _filteredIlceler = [];
                    });
                    _showSnack('Filtreler sıfırlandı');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: deepGreen.withOpacity(0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Sıfırla",
                          style: TextStyle(
                            color: deepGreen.withOpacity(0.7),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Apply Button - Enhanced
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deepGreen,
                    midGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: deepGreen.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: midGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _applyFilters,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Uygula",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              deepGreen,
              midGreen,
              lightGreen,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: deepGreen.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: midGreen.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deepGreen.withOpacity(0.95),
                    midGreen.withOpacity(0.85),
                    lightGreen.withOpacity(0.75),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Coffee Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.coffee_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Uğrak Mekan',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bugün nereye gidelim? ☕',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onLogout != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        onPressed: widget.onLogout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(),
                        tooltip: 'Çıkış Yap',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            vanilla,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: midGreen.withOpacity(0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: deepGreen.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: lightGreen.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                color: deepGreen,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                hintText: 'Mekan ara veya tarif et...',
                hintStyle: TextStyle(
                  color: deepGreen.withOpacity(0.45),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.1,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _triggerSearch(useAI: false);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // AI Button - Deep Green Style
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  deepGreen,
                  deepGreen.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: deepGreen.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_searchController.text.trim().isEmpty) {
                    _showSnack('Lütfen bir arama metni girin');
                    return;
                  }
                  _triggerSearch(useAI: true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter toggle button
          Container(
            decoration: BoxDecoration(
              gradient: isPanelOpen
                  ? LinearGradient(
                      colors: [deepGreen, midGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        lightGreen.withOpacity(0.3),
                        midGreen.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPanelOpen
                    ? deepGreen.withOpacity(0.4)
                    : midGreen.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: isPanelOpen
                  ? [
                      BoxShadow(
                        color: deepGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: IconButton(
              onPressed: () {
                final newState = !isPanelOpen;
                setState(() => isPanelOpen = newState);
                widget.onPanelToggle?.call(newState);
              },
              icon: Icon(
                isPanelOpen ? Icons.close_rounded : Icons.tune_rounded,
                color: isPanelOpen ? Colors.white : deepGreen,
                size: 22,
              ),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
              tooltip: isPanelOpen ? 'Filtreleri kapat' : 'Filtreleri aç',
            ),
          ),
        ],
      ),
    );
  }
}
