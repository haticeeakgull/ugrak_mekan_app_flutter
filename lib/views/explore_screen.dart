import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/post_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/cafe_detail_sheet.dart';
import '../models/cafe_model.dart';
import 'user_profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  List<dynamic> _kafeler = [];
  // Tip güvenliği için List<Map<String, dynamic>> olarak tanımlıyoruz
  List<Map<String, dynamic>> _tumOneriPostlari = [];
  List<Marker> _markers = [];

  bool _isMapLoading = true;
  bool _showCafeCards = false;
  int _currentCafeIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchKafeler();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchKafeler() async {
    try {
      // 1. !inner takısını sildik ki postu olmayan kafeler de gelsin.
      // 2. Filtreyi doğrudan select içinde parantez içinde belirttik.
      final data = await supabase
          .from('ilce_isimli_kafeler')
          .select('''
        *,
        cafe_postlar (
          *,
          profiles!inner (username, is_private),
          ilce_isimli_kafeler (kafe_adi) 
        )
      ''')
          .filter('cafe_postlar.profiles.is_private', 'eq', false);
      // .filter kullanarak 'soft' bir filtreleme yapıyoruz.

      if (mounted) {
        setState(() {
          _kafeler = data;

          // Postları ayrıştırırken hata almamak için boş liste kontrolü ekliyoruz
          _tumOneriPostlari = _kafeler.expand((cafe) {
            final posts = cafe['cafe_postlar'] as List? ?? [];
            return posts.map((post) {
              final postMap = Map<String, dynamic>.from(post);
              if (postMap['ilce_isimli_kafeler'] == null) {
                postMap['ilce_isimli_kafeler'] = {'kafe_adi': cafe['kafe_adi']};
              }
              return postMap;
            });
          }).toList()..shuffle();

          _updateMarkers(); // Haritadaki imleçleri tekrar çiz
          _isMapLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  void _updateMarkers() {
    if (_kafeler.isEmpty) return;
    final double currentZoom = _mapController.camera.zoom;

    _markers = _kafeler.asMap().entries.map((entry) {
      int i = entry.key;
      var cafe = entry.value;
      bool isSelected = i == _currentCafeIndex && _showCafeCards;

      return Marker(
        point: LatLng(cafe['latitude'] ?? 0.0, cafe['longitude'] ?? 0.0),
        width: isSelected ? 100 : 80,
        height: 40,
        child: GestureDetector(
          onTap: () {
            _closeSearch();
            setState(() {
              _showCafeCards = true;
              _currentCafeIndex = i;
              _updateMarkers();
            });
            _pageController.jumpToPage(i);
            _mapController.move(
              LatLng(cafe['latitude'], cafe['longitude']),
              15,
            );
          },
          child: _buildSmartMarker(
            cafe['kafe_adi'] ?? "",
            isSelected,
            currentZoom,
          ),
        ),
      );
    }).toList();
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    if (mounted) setState(() => _searchResults = []);
  }

  Widget _buildSmartMarker(String name, bool isSelected, double zoom) {
    if (zoom < 14.0 && !isSelected) {
      return Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.deepOrange, width: 2),
          ),
        ),
      );
    }
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(maxWidth: 90),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardHeight > 0;
    final bool isSearchActive = _searchFocusNode.hasFocus;

    return GestureDetector(
      onTap: _closeSearch,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _isMapLoading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(39.9042, 32.8597),
                      initialZoom: 13,
                      onTap: (_, __) => _closeSearch(),
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) setState(() => _updateMarkers());
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),

            if (isSearchActive)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0)),
              ),

            if (!isKeyboardOpen && !isSearchActive) ...[
              if (_showCafeCards && _kafeler.isNotEmpty)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 280,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _kafeler.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentCafeIndex = index;
                          _updateMarkers();
                        });
                        _mapController.move(
                          LatLng(
                            _kafeler[index]['latitude'],
                            _kafeler[index]['longitude'],
                          ),
                          15,
                        );
                      },
                      itemBuilder: (context, index) =>
                          _buildCafeCard(_kafeler[index]),
                    ),
                  ),
                ),

              if (_showCafeCards)
                Positioned(
                  right: 20,
                  bottom: 310,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () => setState(() => _showCafeCards = false),
                    child: const Icon(Icons.close, color: Colors.black),
                  ),
                ),

              if (!_showCafeCards) _buildDiscoverySheet(),
            ],

            _buildSearchOverlay(isKeyboardOpen),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.08,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 5),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "Sana Özel Keşifler",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _tumOneriPostlari.length,
                  itemBuilder: (context, index) {
                    final post = _tumOneriPostlari[index];
                    // 'index' değerini metoda parametre olarak geçiyoruz
                    return _buildDiscoveryPostItem(post, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // index parametresi eklendi
  Widget _buildDiscoveryPostItem(Map<String, dynamic> post, int index) {
    final String kullaniciAdi = post['profiles']?['username'] ?? 'Anonim';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post['foto_url'] ?? "",
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.deepOrange,
                        child: Text(
                          kullaniciAdi.isNotEmpty
                              ? kullaniciAdi[0].toUpperCase()
                              : "A",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        kullaniciAdi,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post['baslik'] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['icerik'] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      // Sayfaya git ve dönmesini bekle
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailScreen(
                            allPosts: _tumOneriPostlari,
                            initialIndex: index,
                          ),
                        ),
                      );
                      // Sayfadan geri dönüldüğünde (düzenleme yapılmış olabilir) listeyi tekrar çek
                      _fetchKafeler();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Detayları İncele",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeCard(dynamic cafeData) {
    final List<dynamic> postlar = cafeData['cafe_postlar'] ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 12,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: postlar.isNotEmpty
                  ? Image.network(
                      postlar[0]['foto_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : const Icon(Icons.local_cafe, size: 50),
            ),
          ),
          Expanded(
            flex: 10,
            child: InkWell(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    CafeDetailSheet(cafe: Cafe.fromJson(cafeData)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafeData['kafe_adi'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const Center(
                      child: Text(
                        "Detayları Gör",
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay(bool isKeyboardOpen) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _searchUsers,
                decoration: InputDecoration(
                  hintText: "Arkadaşlarını keşfet...",
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.deepOrange,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _closeSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: BoxConstraints(
                  maxHeight: isKeyboardOpen
                      ? MediaQuery.of(context).size.height * 0.3
                      : MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepOrange,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(user['username'] ?? "Anonim"),
                      onTap: () {
                        _closeSearch();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfileScreen(targetUserId: user['id']),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    final results = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(10);
    if (mounted) {
      setState(() => _searchResults = List<Map<String, dynamic>>.from(results));
    }
  }
}
