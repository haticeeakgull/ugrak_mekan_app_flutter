import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

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

class _ModernSearchExperienceState extends State<ModernSearchExperience> {
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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SupabaseService _supabaseService = SupabaseService();

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color lightGreen = const Color(0xFF9FCB98);
  final Color vanilla = const Color(0xFFF2EDC2);

  static const List<String> _sehirler = ['İstanbul', 'Ankara', 'İzmir'];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerSearch({bool useAI = false}) {
    final String? ilParam = _isNearby ? _nearbyCity : selectedCity;
    final String searchText = _searchController.text.trim();
    
    // AI kullanılıyorsa searchText'i gönder, değilse boş string
    // Home screen bu parametreyi kullanarak hangi arama metodunu çağıracağına karar verecek
    widget.onSearch(
      ilParam,
      selectedDistrict != null ? [selectedDistrict!] : [],
      selectedVibes,
      useAI ? searchText : '', // AI ise text gönder, değilse boş
      _isNearby ? _userLat : null,
      _isNearby ? _userLng : null,
    );
  }
  
  void _triggerDirectSearch() {
    // Direct search without AI - but we need to pass the search text differently
    final String? ilParam = _isNearby ? _nearbyCity : selectedCity;
    final String searchText = _searchController.text.trim();
    
    // Normal aramada searchText'i özel bir formatta gönderelim
    // Örneğin "DIRECT:" prefix'i ile
    widget.onSearch(
      ilParam,
      selectedDistrict != null ? [selectedDistrict!] : [],
      selectedVibes,
      'DIRECT:$searchText', // DIRECT prefix'i ile normal arama olduğunu belirt
      _isNearby ? _userLat : null,
      _isNearby ? _userLng : null,
    );
  }
  
  void _triggerAISearch() {
    // AI-assisted search
    if (_searchController.text.trim().isEmpty) {
      _showSnack('Lütfen bir arama metni girin');
      return;
    }
    _triggerSearch(useAI: true);
  }

  Future<void> _onCitySelected(String city) async {
    if (city == '📍 Yakınım') {
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
    } catch (_) {
      if (mounted) setState(() => _isLoadingIlceler = false);
    }
    // _triggerSearch() kaldırıldı — sadece "Uygula"ya basınca arama yapılacak
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
      // Yakınım seçilince otomatik arama yap (konum alındı, anlamlı)
      _triggerSearch();
    } catch (e) {
      _showSnack('Konum alınamadı.');
      setState(() => _isLoadingLocation = false);
    }
  }

  /// Koordinata en yakın desteklenen şehri döner
  String? _findNearestCity(double lat, double lng) {
    const cities = {
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
                                    ? "📍 Yakınım"
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isExpanded
              ? Colors.white.withOpacity(0.55)
              : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? deepGreen.withOpacity(0.35)
                : midGreen.withOpacity(0.2),
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: () =>
                  setState(() => expandedIndex = isExpanded ? null : index),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: deepGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: deepGreen, size: 24),
              ),
              title: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: deepGreen,
                  letterSpacing: 1.5,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: hasSelection
                        ? deepGreen
                        : deepGreen.withOpacity(0.6),
                    fontWeight:
                        hasSelection ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              trailing: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: deepGreen,
                  size: 28,
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: content,
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
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
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: deepGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Konum alınıyor...',
                style: TextStyle(color: deepGreen, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ['📍 Yakınım', ..._sehirler].map((c) {
        final isNearbyChip = c == '📍 Yakınım';
        final isSel = isNearbyChip ? _isNearby : selectedCity == c;
        return ChoiceChip(
          label: Text(
            c,
            style: TextStyle(
              color: isSel ? Colors.white : deepGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSel,
          onSelected: (v) {
            if (!v) {
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
              // seçim kaldırılınca arama yapma
            } else {
              _onCitySelected(c);
            }
          },
          selectedColor: deepGreen,
          backgroundColor: Colors.white.withOpacity(0.3),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDistrictScroll() {
    if (_isLoadingIlceler) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2, color: deepGreen),
        ),
      );
    }

    if (_filteredIlceler.isEmpty) {
      return Text(
        'Bu şehir için ilçe bulunamadı.',
        style: TextStyle(color: deepGreen.withOpacity(0.5), fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filteredIlceler.map((s) {
        bool isSel = selectedDistrict == s;
        return ActionChip(
          label: Text(
            s,
            style: TextStyle(
              color: isSel ? Colors.white : deepGreen,
              fontSize: 13,
            ),
          ),
          onPressed: () {
            setState(() => selectedDistrict = isSel ? null : s);
            // arama yapma, "Uygula"ya bırak
          },
          backgroundColor: isSel ? midGreen : Colors.white.withOpacity(0.3),
          side: BorderSide(
            color: isSel ? deepGreen.withOpacity(0.2) : Colors.transparent,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVibeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.vibeler.map((v) {
        bool isSel = selectedVibes.contains(v);
        return FilterChip(
          label: Text(
            v,
            style: TextStyle(
              color: isSel ? Colors.white : deepGreen,
              fontSize: 12,
            ),
          ),
          selected: isSel,
          onSelected: (val) {
            setState(
              () => val ? selectedVibes.add(v) : selectedVibes.remove(v),
            );
            // arama yapma, "Uygula"ya bırak
          },
          selectedColor: midGreen,
          backgroundColor: Colors.white.withOpacity(0.2),
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedCity = null;
                selectedDistrict = null;
                selectedVibes.clear();
                _searchController.clear();
                expandedIndex = null;
                _isNearby = false;
                _nearbyCity = null;
                _userLat = null;
                _userLng = null;
                _filteredIlceler = [];
              });
              // sıfırlayınca panel açık kalsın, arama yapma
            },
            child: Text(
              "Sıfırla",
              style: TextStyle(
                color: deepGreen.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _triggerDirectSearch();
              setState(() => isPanelOpen = false);
              widget.onPanelToggle?.call(false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: deepGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Uygula",
              style: TextStyle(fontWeight: FontWeight.bold),
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
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              vanilla.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: deepGreen.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    vanilla.withOpacity(0.5),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: deepGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.coffee_rounded,
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
                                    'Uğrak Mekan',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: deepGreen,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bugün nereye gidiyoruz? ☕',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: midGreen,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.onLogout != null)
                    Container(
                      decoration: BoxDecoration(
                        color: deepGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: widget.onLogout,
                        icon: Icon(
                          Icons.logout_rounded,
                          color: deepGreen,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: midGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: deepGreen.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: deepGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                color: deepGreen,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Mekan ara veya tarif et...',
                hintStyle: TextStyle(
                  color: deepGreen.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (value) {
                // Enter tuşuna basıldığında direkt arama
                if (value.trim().isNotEmpty) {
                  _triggerDirectSearch();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // AI Button
          Container(
            decoration: BoxDecoration(
              color: deepGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _triggerAISearch,
              icon: Icon(
                Icons.auto_awesome_rounded,
                color: deepGreen,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'AI ile ara',
            ),
          ),
          const SizedBox(width: 4),
          // Filter toggle button
          Container(
            decoration: BoxDecoration(
              color: isPanelOpen 
                  ? deepGreen.withOpacity(0.15) 
                  : deepGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                final newState = !isPanelOpen;
                setState(() => isPanelOpen = newState);
                widget.onPanelToggle?.call(newState);
              },
              icon: Icon(
                isPanelOpen ? Icons.close : Icons.tune_rounded,
                color: deepGreen,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: isPanelOpen ? 'Filtreleri kapat' : 'Filtreleri aç',
            ),
          ),
        ],
      ),
    );
  }
}
