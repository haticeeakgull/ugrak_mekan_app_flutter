import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/explore_service.dart';

class MapExploreController extends ChangeNotifier {
  final ExploreService _service = ExploreService();

  GoogleMapController? mapController;
  PageController? _pageController;
  
  PageController get pageController {
    if (_pageController == null || !_pageController!.hasClients) {
      _pageController = PageController(
        viewportFraction: 0.88,
        initialPage: currentCafeIndex,
      );
    }
    return _pageController!;
  }

  LatLng userLocation = const LatLng(39.9334, 32.8597); // Türkiye merkezi
  List<dynamic> kafeler = [];
  Map<String, dynamic> kafeDetailsCache = {}; // Detay cache
  List<Map<String, dynamic>>? globalDiscoveryPosts = [];
  Set<Marker> markers = {};

  bool isFetching = false;
  bool isMapLoading = true;
  bool showCafeCards = false;
  int currentCafeIndex = 0;
  int discoveryOffset = 0; // Pagination için

  void setMapController(GoogleMapController controller) {
    mapController = controller;
    updateMarkers();
  }

  Future<void> initLocation() async {
    try {
      // Paralel olarak hem konum hem de kafeleri çek
      final results = await Future.wait([
        _service.getCurrentLocation(),
        _service.fetchAllKafeler(),
      ]);

      final pos = results[0] as Position;
      userLocation = LatLng(pos.latitude, pos.longitude);
      kafeler = results[1] as List<dynamic>;

      isMapLoading = false;

      // Markerları hazırla
      updateMarkers();
      
      // Keşfet postlarını arka planda yükle (UI'ı bloklamaz)
      loadGlobalDiscovery();
    } catch (e) {
      debugPrint("Başlatma hatası: $e");
      isMapLoading = false;
      updateMarkers();
      loadGlobalDiscovery();
    }
  }

  // Harita her durduğunda veriyi sırala
  Future<void> updateLocationAndSort(LatLng newLocation) async {
    userLocation = newLocation;
    if (globalDiscoveryPosts != null && globalDiscoveryPosts!.isNotEmpty) {
      _sortPostsByDistance();
      notifyListeners();
    }
  }

  Future<void> loadGlobalDiscovery({bool loadMore = false}) async {
    if (isFetching) return;
    isFetching = true;

    try {
      if (!loadMore) {
        discoveryOffset = 0;
        globalDiscoveryPosts = [];
      }

      final List<Map<String, dynamic>> rawPosts = await _service
          .fetchDiscoveryPostsRaw(limit: 20, offset: discoveryOffset);

      if (rawPosts.isEmpty) {
        isFetching = false;
        notifyListeners();
        return;
      }

      List<Map<String, dynamic>> processedPosts = [];
      for (var post in rawPosts) {
        final cafeInfo = post['ilce_isimli_kafeler'];
        if (cafeInfo == null) continue;

        final postMap = Map<String, dynamic>.from(post);
        postMap['kafe_adi'] = cafeInfo['kafe_adi'] ?? 'Bilinmeyen Kafe';

        double cafeLat = double.parse(cafeInfo['latitude'].toString());
        double cafeLng = double.parse(cafeInfo['longitude'].toString());

        postMap['distance'] = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          cafeLat,
          cafeLng,
        );

        processedPosts.add(postMap);
      }

      if (loadMore) {
        globalDiscoveryPosts!.addAll(processedPosts);
      } else {
        globalDiscoveryPosts = processedPosts;
      }

      globalDiscoveryPosts!.sort((a, b) => a['distance'].compareTo(b['distance']));
      discoveryOffset += rawPosts.length;
      isFetching = false;
      notifyListeners();
    } catch (e) {
      debugPrint("loadGlobalDiscovery hatası: $e");
      if (!loadMore) globalDiscoveryPosts = [];
      isFetching = false;
      notifyListeners();
    }
  }

  void _sortPostsByDistance() {
    if (globalDiscoveryPosts == null) return;
    globalDiscoveryPosts!.sort(
      (a, b) => a['distance'].compareTo(b['distance']),
    );
  }

  // Markerları TÜM listeye göre oluşturur (hafif veri)
  void updateMarkers() {
    Set<Marker> newMarkers = {};
    for (int i = 0; i < kafeler.length; i++) {
      var cafe = kafeler[i];
      if (cafe['latitude'] == null || cafe['longitude'] == null) continue;

      bool isSelected = i == currentCafeIndex && showCafeCards;
      newMarkers.add(
        Marker(
          markerId: MarkerId(cafe['id'].toString()),
          clusterManagerId: const ClusterManagerId("cafe_cluster"),
          position: LatLng(
            double.parse(cafe['latitude'].toString()),
            double.parse(cafe['longitude'].toString()),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          onTap: () => onMarkerTapped(i),
        ),
      );
    }
    markers = newMarkers;
    notifyListeners();
  }

  // Kafe detaylarını cache'den veya API'den çek
  Future<Map<String, dynamic>?> getKafeDetails(String kafeId) async {
    if (kafeDetailsCache.containsKey(kafeId)) {
      return kafeDetailsCache[kafeId];
    }

    final details = await _service.fetchKafeDetails(kafeId);
    if (details != null) {
      kafeDetailsCache[kafeId] = details;
    }
    return details;
  }

  void onMarkerTapped(int index) {
    debugPrint('🎯 Marker tapped: index=$index, cafe=${kafeler[index]['kafe_adi']}');
    currentCafeIndex = index;
    showCafeCards = true;
    
    // PageController'ı yeniden oluştur doğru initial page ile
    _pageController?.dispose();
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: index,
    );
    debugPrint('📄 New PageController created with initialPage=$index');
    
    updateMarkers();

    // Haritayı seçili kafeye odakla
    mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(
          double.parse(kafeler[index]['latitude'].toString()),
          double.parse(kafeler[index]['longitude'].toString()),
        ),
      ),
    );
    notifyListeners();
  }

  void toggleCafeCards(bool show) {
    showCafeCards = show;
    if (!show) {
      // Kartlar kapandığında PageController'ı temizle
      _pageController?.dispose();
      _pageController = null;
    }
    notifyListeners();
  }
  
  @override
  void dispose() {
    _pageController?.dispose();
    mapController?.dispose();
    super.dispose();
  }
}
