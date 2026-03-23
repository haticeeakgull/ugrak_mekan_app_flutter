import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  List<Map<String, dynamic>> _searchResults = [];
  List<dynamic> _kafeler = [];
  List<dynamic> _tumOneriPostlari = [];
  List<Marker> _markers = [];

  bool _isMapLoading = true;
  bool _showCafeCards = false;

  int _currentCafeIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchKafeler();
  }

  Future<void> _fetchKafeler() async {
    try {
      final data = await supabase.from('ilce_isimli_kafeler').select('''
        *,
        cafe_postlar (
          foto_url,
          baslik
        )
      ''');

      setState(() {
        _kafeler = data;

        _tumOneriPostlari =
            _kafeler
                .expand((cafe) => (cafe['cafe_postlar'] as List? ?? []))
                .toList()
              ..shuffle();

        _updateMarkers();

        _isMapLoading = false;
      });
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");

      setState(() => _isMapLoading = false);
    }
  }

  void _updateMarkers() {
    _markers = _kafeler.asMap().entries.map((entry) {
      int i = entry.key;

      var cafe = entry.value;

      return Marker(
        point: LatLng(cafe['latitude'] ?? 0.0, cafe['longitude'] ?? 0.0),

        width: 100,
        height: 50,

        child: GestureDetector(
          onTap: () {
            setState(() {
              _showCafeCards = true;
              _currentCafeIndex = i;
            });

            _pageController.jumpToPage(i);

            _mapController.move(
              LatLng(cafe['latitude'], cafe['longitude']),
              15,
            );
          },

          child: _buildAirbnbMarker(
            cafe['kafe_adi'] ?? "",
            i == _currentCafeIndex,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAirbnbMarker(String name, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: isSelected ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),

      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isMapLoading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(39.9042, 32.8597),
                    initialZoom: 13,
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

          if (_showCafeCards)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 270,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _kafeler.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCafeIndex = index;
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

          /// ❌ KART KAPATMA BUTONU
          if (_showCafeCards)
            Positioned(
              right: 20,
              bottom: 310,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _showCafeCards = false;
                  });
                },
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),

          if (!_showCafeCards) _buildDiscoverySheet(),

          _buildSearchOverlay(),
        ],
      ),
    );
  }

  Widget _buildDiscoverySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.85,

      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),

          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Sana Özel Keşifler",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _tumOneriPostlari.length,
                  itemBuilder: (context, index) {
                    final post = _tumOneriPostlari[index];

                    return Column(
                      children: [
                        Image.network(
                          post['foto_url'] ?? "",
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.cover,
                        ),

                        ListTile(
                          title: Text(
                            post['baslik'] ?? "",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(
                            Icons.favorite_border,
                            color: Colors.deepOrange,
                          ),
                        ),

                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCafeCard(dynamic cafeData) {
    final List<dynamic> postlar = cafeData['cafe_postlar'] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),

      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: postlar.isNotEmpty
                  ? PageView.builder(
                      itemCount: postlar.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          postlar[index]['foto_url'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      },
                    )
                  : Container(
                      color: Colors.orange[100],
                      child: const Center(
                        child: Icon(Icons.local_cafe, size: 60),
                      ),
                    ),
            ),
          ),

          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                final cafeModel = Cafe.fromJson(cafeData);

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => CafeDetailSheet(cafe: cafeModel),
                );
              },

              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafeData['kafe_adi'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      postlar.isNotEmpty
                          ? postlar[0]['baslik']
                          : "Fotoğraf yok",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                    ),

                    const Spacer(),

                    const Center(
                      child: Text(
                        "Detayları Gör",
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
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
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
                onChanged: _searchUsers,
                decoration: const InputDecoration(
                  hintText: "Arkadaşlarını keşfet...",
                  prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),

            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_searchResults[index]['username'] ?? ""),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          targetUserId: _searchResults[index]['id'],
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

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final results = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(5);

    setState(() => _searchResults = List<Map<String, dynamic>>.from(results));
  }
}
