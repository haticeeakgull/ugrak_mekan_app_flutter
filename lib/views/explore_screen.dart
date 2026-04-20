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
    _controller = MapExploreController();
    _controller.initLocation();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _searchFocusNode.addListener(() => setState(() {}));
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
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _controller.userLocation,
                      zoom: 11,
                    ),
                    onMapCreated: _controller.setMapController,
                    onCameraIdle: _controller.fetchVisibleKafeler,
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
              DiscoverySheetWidget(discoveryPosts: _controller.discoveryPosts),

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
