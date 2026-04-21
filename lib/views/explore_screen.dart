import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/map_explore_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/explore/cafe_cards.dart';
import '../widgets/explore/discovery_sheet.dart';
import '../widgets/explore/friends_search.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late MapExploreController _controller;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // HATALI YER: context.read yerine direkt oluşturuyoruz
    _controller = MapExploreController();

    // Verileri çekmeye başla
    _controller.initLocation();

    // Değişiklikleri dinle ve ekranı güncelle
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isSearchActive = _searchFocusNode.hasFocus;

    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
        _controller.toggleCafeCards(false);
      },
      child: AppScaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // GOOGLE MAP
            _controller.isMapLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF346739)),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _controller.userLocation,
                      zoom: 11,
                    ),
                    onMapCreated: _controller.setMapController,
                    onCameraIdle: () async {
                      final controller = await _controller.mapController
                          ?.getVisibleRegion();
                      if (controller != null) {
                        // Haritanın merkezini al ve listeyi ona göre tekrar diz
                        final center = LatLng(
                          (controller.northeast.latitude +
                                  controller.southwest.latitude) /
                              2,
                          (controller.northeast.longitude +
                                  controller.southwest.longitude) /
                              2,
                        );
                        _controller.updateLocationAndSort(center);
                      }
                    },
                    markers: _controller.markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onTap: (_) => _controller.toggleCafeCards(false),
                    clusterManagers: {
                      ClusterManager(
                        clusterManagerId: const ClusterManagerId(
                          "cafe_cluster",
                        ),
                        onClusterTap: (cluster) =>
                            _controller.mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(cluster.position, 14),
                            ),
                      ),
                    },
                  ),

            // BLUR FOR SEARCH
            if (isSearchActive)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.1)),
                ),
              ),

            // CAFE CARDS
            if (!isKeyboardOpen && !isSearchActive && _controller.showCafeCards)
              CafeCardsWidget(controller: _controller),

            // DISCOVERY SHEET
            if (!isKeyboardOpen &&
                !isSearchActive &&
                !_controller.showCafeCards)
              DiscoverySheetWidget(
                discoveryPosts: _controller.globalDiscoveryPosts,
                onLoadMore: () => _controller.loadGlobalDiscovery(loadMore: true),
                isLoading: _controller.isFetching,
              ),

            // SEARCH BAR
            FriendsSearchWidget(
              focusNode: _searchFocusNode,
              onSearchClosed: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
