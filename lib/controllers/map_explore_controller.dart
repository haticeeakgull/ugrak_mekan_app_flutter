import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/explore_service.dart';

class MapExploreController extends ChangeNotifier {
  final ExploreService _service = ExploreService();

  GoogleMapController? mapController;
  final PageController pageController = PageController(viewportFraction: 0.88);

  LatLng userLocation = const LatLng(38.4237, 27.1428);
  List<dynamic> kafeler = [];
  List<Map<String, dynamic>>? discoveryPosts;
  Set<Marker> markers = {};

  bool isFetching = false;
  bool isMapLoading = true;
  bool showCafeCards = false;
  int currentCafeIndex = 0;

  void setMapController(GoogleMapController controller) {
    mapController = controller;
    fetchVisibleKafeler();
  }

  Future<void> initLocation() async {
    try {
      final pos = await _service.getCurrentLocation();
      userLocation = LatLng(pos.latitude, pos.longitude);
      isMapLoading = false;
      notifyListeners();
    } catch (e) {
      isMapLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchVisibleKafeler() async {
    if (mapController == null || isFetching) return;
    isFetching = true;

    try {
      final bounds = await mapController!.getVisibleRegion();
      kafeler = await _service.fetchKafeler(bounds);
      _prepareDiscoveryPosts();
      updateMarkers();
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      isFetching = false;
      notifyListeners();
    }
  }

  void _prepareDiscoveryPosts() {
    List<Map<String, dynamic>> tempPosts = [];
    for (var cafe in kafeler) {
      final posts = cafe['cafe_postlar'] as List? ?? [];
      for (var post in posts) {
        final profile = post['profiles'];
        if (profile != null &&
            (profile['is_private'] == false || profile['is_private'] == null)) {
          final postMap = Map<String, dynamic>.from(post);
          postMap['kafe_adi'] = cafe['kafe_adi'];
          tempPosts.add(postMap);
        }
      }
    }
    discoveryPosts = tempPosts..shuffle();
  }

  void updateMarkers() {
    Set<Marker> newMarkers = {};
    for (int i = 0; i < kafeler.length; i++) {
      var cafe = kafeler[i];
      if (cafe['latitude'] == null || cafe['longitude'] == null) continue;

      bool isSelected = i == currentCafeIndex && showCafeCards;
      newMarkers.add(
        Marker(
          markerId: MarkerId(cafe['id'].toString()),
          position: LatLng(
            double.parse(cafe['latitude'].toString()),
            double.parse(cafe['longitude'].toString()),
          ),
          clusterManagerId: const ClusterManagerId("cafe_cluster"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
          ),
          onTap: () => onMarkerTapped(i),
        ),
      );
    }
    markers = newMarkers;
    notifyListeners();
  }

  void onMarkerTapped(int index) {
    currentCafeIndex = index;
    showCafeCards = true;
    updateMarkers();

    if (pageController.hasClients) {
      pageController.jumpToPage(index);
    }

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
    notifyListeners();
  }
}
