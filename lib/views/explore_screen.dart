import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // gmaps alias kaldırıldı
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/views/post_detail_screen.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
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
  final PageController _pageController = PageController(viewportFraction: 0.88);
  final FocusNode _searchFocusNode = FocusNode();

  GoogleMapController? _mapController;

  List<Map<String, dynamic>> _searchResults = [];
  List<dynamic> _kafeler = [];
  List<Map<String, dynamic>> _tumOneriPostlari = [];
  Set<Marker> _markers = {};

  bool _isMapLoading = true;
  bool _showCafeCards = false;
  int _currentCafeIndex = 0;
  LatLng _userLocation = const LatLng(38.4237, 27.1428); // Varsayılan İzmir

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeScreen() async {
    await _determinePosition();
    await _fetchNearbyKafeler();
  }

  // --- KONUM SERVİSİ ---
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Lütfen konum servisini açın.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation, 14.5),
      );
    }
  }

  // --- SUPABASE VERİ ÇEKME ---
  Future<void> _fetchNearbyKafeler() async {
    try {
      final List<dynamic> data = await supabase.rpc(
        'get_nearby_cafes',
        params: {
          'user_lat': _userLocation.latitude,
          'user_long': _userLocation.longitude,
          'radius_km': 30.0,
        },
      );

      if (data.isEmpty) {
        if (mounted) setState(() => _isMapLoading = false);
        return;
      }

      final fullData = await supabase
          .from('ilce_isimli_kafeler')
          .select('*, cafe_postlar(*, profiles(username, is_private))')
          .inFilter('id', data.map((e) => e['id']).toList());

      if (mounted) {
        setState(() {
          _kafeler = fullData;
          _prepareDiscoveryPosts();
          _updateGoogleMarkers();
          _isMapLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  void _prepareDiscoveryPosts() {
    List<Map<String, dynamic>> tempPosts = [];
    for (var cafe in _kafeler) {
      final posts = cafe['cafe_postlar'] as List? ?? [];
      for (var post in posts) {
        if (post['profiles']?['is_private'] == false) {
          final postMap = Map<String, dynamic>.from(post);
          postMap['kafe_adi'] = cafe['kafe_adi'];
          tempPosts.add(postMap);
        }
      }
    }
    _tumOneriPostlari = tempPosts..shuffle();
  }

  void _updateGoogleMarkers() {
    Set<Marker> newMarkers = {};
    for (int i = 0; i < _kafeler.length; i++) {
      var cafe = _kafeler[i];
      bool isSelected = i == _currentCafeIndex && _showCafeCards;

      newMarkers.add(
        Marker(
          markerId: MarkerId(cafe['id'].toString()),
          position: LatLng(cafe['latitude'], cafe['longitude']),
          // KÜMELEME İÇİN KRİTİK: clusterManagerId atıyoruz
          clusterManagerId: const ClusterManagerId("cafe_cluster"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
          ),
          onTap: () {
            _closeSearch();
            setState(() {
              _showCafeCards = true;
              _currentCafeIndex = i;
              _updateGoogleMarkers();
            });
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutQuart,
            );
          },
        ),
      );
    }
    setState(() => _markers = newMarkers);
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    if (mounted) setState(() => _searchResults = []);
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isSearchActive = _searchFocusNode.hasFocus;

    return GestureDetector(
      onTap: _closeSearch,
      child: AppScaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _isMapLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _userLocation,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    // GOOGLE NATIVE CLUSTERING AYARLARI
                    clusterManagers: {
                      ClusterManager(
                        clusterManagerId: const ClusterManagerId(
                          "cafe_cluster",
                        ),
                        onClusterTap: (cluster) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(cluster.position, 16),
                          );
                        },
                      ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onTap: (_) {
                      _closeSearch();
                      setState(() => _showCafeCards = false);
                    },
                  ),

            if (isSearchActive)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.15)),
              ),

            // --- KAFE KARTLARI ---
            if (!isKeyboardOpen &&
                !isSearchActive &&
                _showCafeCards &&
                _kafeler.isNotEmpty)
              Positioned(
                bottom: 30,
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
                        _updateGoogleMarkers();
                      });
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(
                            _kafeler[index]['latitude'],
                            _kafeler[index]['longitude'],
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, index) =>
                        _buildCafeCard(_kafeler[index]),
                  ),
                ),
              ),

            // --- KEŞİF PANELİ ---
            if (!isKeyboardOpen && !isSearchActive && !_showCafeCards)
              _buildDiscoverySheet(),

            _buildSearchOverlay(isKeyboardOpen),
          ],
        ),
      ),
    );
  }

  // --- DİĞER UI BİLEŞENLERİ (Öncekiyle Aynı, Mantık Korundu) ---
  // (Buradaki _buildDiscoverySheet, _buildCafeCard vb. metodlar senin kodunla aynıdır)

  Widget _buildDiscoverySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.14, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Sana Özel Keşifler",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              Expanded(
                child: _tumOneriPostlari.isEmpty
                    ? const Center(
                        child: Text("Yakınlarda keşfedilecek bir şey yok."),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _tumOneriPostlari.length,
                        itemBuilder: (context, index) =>
                            _buildDiscoveryPostItem(
                              _tumOneriPostlari[index],
                              index,
                            ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryPostItem(Map<String, dynamic> post, int index) {
    final String username = post['profiles']?['username'] ?? 'Anonim';
    return Container(
      height: 480,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post['foto_url'] ?? "",
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey[100]),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black12,
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepOrange,
                        child: Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post['baslik'] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['kafe_adi'] ?? "",
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => PostDetailScreen(
                          allPosts: _tumOneriPostlari,
                          initialIndex: index,
                        ),
                      ),
                    ),
                    child: const Text("Detayları İncele"),
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
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              child: postlar.isNotEmpty
                  ? Image.network(
                      postlar[0]['foto_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : const Center(
                      child: Icon(
                        Icons.local_cafe,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cafeData['kafe_adi'] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    "${cafeData['ilce'] ?? ''} • Cafe",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) =>
                          CafeDetailSheet(cafe: Cafe.fromJson(cafeData)),
                    ),
                    child: const Text(
                      "Tüm Detayları Gör →",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            Material(
              elevation: 10,
              shadowColor: Colors.black26,
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
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepOrange,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(user['username'] ?? "Anonim"),
                      onTap: () {
                        _closeSearch();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) =>
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
      setState(() => _searchResults = []);
      return;
    }
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .limit(8);
      if (mounted)
        setState(() => _searchResults = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint("Arama hatası: $e");
    }
  }

  void _showSnackBar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
