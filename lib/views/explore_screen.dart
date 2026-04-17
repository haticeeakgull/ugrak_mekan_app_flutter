import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  List<Map<String, dynamic>>? _tumOneriPostlari;
  Set<Marker> _markers = {};

  bool _isMapLoading = true;
  bool _showCafeCards = false;
  int _currentCafeIndex = 0;
  LatLng _userLocation = const LatLng(38.4237, 27.1428); // İzmir Default

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeScreen() async {
    // Latency'yi önlemek için konumun gelmesini BEKLEMEDEN kafeleri çekiyoruz
    _fetchKafeler();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation, 11.0),
        );
      }
    } catch (e) {
      debugPrint("Konum alınamadı: $e");
    }
  }

  // Latency ve görünmeme sorununu çözen ana fonksiyon
  Future<void> _fetchKafeler() async {
    try {
      List<dynamic> allKafeler = [];
      int from = 0;
      int to = 999;
      bool hasMore = true;

      // Tüm veriler bitene kadar 1000'er 1000'er çekiyoruz
      while (hasMore) {
        final res = await supabase
            .from('ilce_isimli_kafeler')
            .select('''
            *,
            cafe_gorselleri(*),
            cafe_postlar (
              *,
              profiles (*)
            )
          ''')
            .range(from, to);

        if (res != null && res.isNotEmpty) {
          allKafeler.addAll(res);

          // Eğer gelen veri 1000'den azsa, çekilecek başka veri kalmamıştır
          if (res.length < 1000) {
            hasMore = false;
          } else {
            from += 1000;
            to += 1000;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        // Debug: Kaç tane geldiğini buradan teyit et
        debugPrint(
          "DEBUG: Veritabanından toplam ${allKafeler.length} kafe çekildi.",
        );

        setState(() {
          _kafeler = allKafeler;
          _isMapLoading = false;
        });

        _prepareDiscoveryPosts();
        _updateGoogleMarkers();
      }
    } catch (e) {
      debugPrint("DEBUG: Çekme hatası: $e");
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  void _prepareDiscoveryPosts() {
    List<Map<String, dynamic>> tempPosts = [];

    print("DEBUG: Toplam ${_kafeler.length} adet kafe taranıyor...");

    for (var cafe in _kafeler) {
      // 1. İlişki adının doğruluğundan emin ol (PostgreSQL'deki tablo adı veya foreign key)
      final posts = cafe['cafe_postlar'] as List? ?? [];

      if (posts.isEmpty) {
        print("DEBUG: ${cafe['kafe_adi']} için hiç post bulunamadı.");
      }

      for (var post in posts) {
        // 2. Kontrolü esnetiyoruz: Profile null değilse ve gizli değilse (veya gizlilik set edilmemişse)
        final profile = post['profiles'];
        bool isVisible =
            profile != null &&
            (profile['is_private'] == false || profile['is_private'] == null);

        if (isVisible) {
          final postMap = Map<String, dynamic>.from(post);
          postMap['kafe_adi'] = cafe['kafe_adi']; // Kafe adını ekle
          tempPosts.add(postMap);
        } else {
          print(
            "DEBUG: Bir post gizlilik ayarı veya eksik profil nedeniyle atlandı.",
          );
        }
      }
    }

    print("DEBUG: Toplam ${tempPosts.length} post keşif için hazırlandı.");

    setState(() {
      // Eğer tempPosts boşsa bile [] set et ki loading sönüp "Bulunamadı" desin
      // Eğer doluysa shuffle yapıp gösterir
      _tumOneriPostlari = tempPosts..shuffle();
    });
  }

  void _updateGoogleMarkers() {
    Set<Marker> newMarkers = {};
    for (int i = 0; i < _kafeler.length; i++) {
      var cafe = _kafeler[i];

      // Koordinat null ise atla
      if (cafe['latitude'] == null || cafe['longitude'] == null) {
        debugPrint("DEBUG: ${cafe['kafe_adi']} için koordinat yok!");
        continue;
      }

      try {
        double lat = double.parse(cafe['latitude'].toString());
        double lng = double.parse(cafe['longitude'].toString());

        bool isSelected = i == _currentCafeIndex && _showCafeCards;

        newMarkers.add(
          Marker(
            markerId: MarkerId(cafe['id'].toString()),
            position: LatLng(lat, lng),
            clusterManagerId: const ClusterManagerId("cafe_cluster"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
            ),
            onTap: () {
              _closeSearch();
              setState(() {
                _currentCafeIndex = i;
                _showCafeCards = true;
              });
              _updateGoogleMarkers();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(i);
                }
              });

              _mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(
                    double.parse(cafe['latitude'].toString()),
                    double.parse(cafe['longitude'].toString()),
                  ),
                ),
              );
            },
          ),
        );
      } catch (e) {
        debugPrint("DEBUG: ${cafe['kafe_adi']} koordinat parse hatası: $e");
      }
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
                      zoom: 10,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    clusterManagers: {
                      ClusterManager(
                        clusterManagerId: const ClusterManagerId(
                          "cafe_cluster",
                        ),
                        onClusterTap: (cluster) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(cluster.position, 14),
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

            // KAFE KARTLARI
            if (!isKeyboardOpen &&
                !isSearchActive &&
                _showCafeCards &&
                _kafeler.isNotEmpty)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 25, bottom: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FloatingActionButton.small(
                          heroTag: "close_cards",
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.close, color: Colors.black),
                          onPressed: () =>
                              setState(() => _showCafeCards = false),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 280,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _kafeler.length,
                        onPageChanged: (index) {
                          setState(() => _currentCafeIndex = index);
                          _updateGoogleMarkers();
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(
                                double.parse(
                                  _kafeler[index]['latitude'].toString(),
                                ),
                                double.parse(
                                  _kafeler[index]['longitude'].toString(),
                                ),
                              ),
                            ),
                          );
                        },
                        itemBuilder: (context, index) =>
                            _buildCafeCard(_kafeler[index]),
                      ),
                    ),
                  ],
                ),
              ),

            if (!isKeyboardOpen && !isSearchActive && !_showCafeCards)
              _buildDiscoverySheet(),

            _buildSearchOverlay(isKeyboardOpen),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeCard(dynamic cafeData) {
    // Veriyi modelimize çeviriyoruz
    final cafe = Cafe.fromJson(cafeData);
    String? kapakFoto;

    // Fotoğraf seçme mantığını sadece değişkeni atamak için kullanıyoruz
    if (cafe.gorseller.isNotEmpty) {
      // Önceliğe göre sırala ve en üsttekini al
      // Not: sort() listeyi yerinde değiştirir, o yüzden bir yere atamana gerek yok.
      cafe.gorseller.sort(
        (a, b) =>
            (b['oncelik_sirasi'] ?? 0).compareTo(a['oncelik_sirasi'] ?? 0),
      );
      kapakFoto = cafe.gorseller[0]['foto_url'];
    }

    // RETURN ifadesi if bloğunun DIŞINDA olmalı ki liste boş olsa bile kart çizilebilsin
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
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
              child: kapakFoto != null
                  ? Image.network(
                      kapakFoto,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Icon(
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
                    cafe.kafeAdi, // Artık cafeData['kafe_adi'] yerine modelden çekebilirsin
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${cafe.ilceAdi} • Cafe",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CafeDetailSheet(
                        cafe:
                            cafe, // Zaten modelimiz hazır, direkt gönderiyoruz
                      ),
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
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
                child: _tumOneriPostlari == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      )
                    : _tumOneriPostlari!.isEmpty
                    ? const Center(
                        child: Text("Henüz keşfedilecek post bulunamadı."),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        // Null safety için ! kullandık çünkü yukarıda kontrol ettik
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _tumOneriPostlari!.length,
                        itemBuilder: (context, index) =>
                            _buildDiscoveryPostItem(
                              _tumOneriPostlari![index],
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
    // Post içindeki profilden username çekme (Eğer null gelirse Anonim yaz)
    final String username = post['profiles'] != null
        ? post['profiles']['username'] ?? 'Anonim'
        : 'Anonim';

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
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                    onPressed: () {
                      if (_tumOneriPostlari != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => PostDetailScreen(
                              allPosts: _tumOneriPostlari!,
                              initialIndex: index,
                            ),
                          ),
                        );
                      }
                    },
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
