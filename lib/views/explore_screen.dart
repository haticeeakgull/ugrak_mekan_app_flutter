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
  List<Marker> _markers = [];
  bool _isMapLoading = true;
  int _currentCafeIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchKafeler();
  }

  // 1. DÜZELTİLMİŞ FETCH SORGUSU: Join işlemi yapıyoruz
  Future<void> _fetchKafeler() async {
    try {
      // ilce_isimli_kafeler'i alırken, ona bağlı cafe_postlar içindeki verileri de çekiyoruz
      final data = await supabase.from('ilce_isimli_kafeler').select('''
        *,
        cafe_postlar (
          foto_url,
          baslik
        )
      ''');

      setState(() {
        _kafeler = data;
        _updateMarkers();
        _isMapLoading = false;
      });
    } catch (e) {
      debugPrint("Veri çekme hatası (Join): $e");
    }
  }

  void _updateMarkers() {
    _markers = _kafeler.asMap().entries.map((entry) {
      int i = entry.key;
      var cafe = entry.value;
      return Marker(
        point: LatLng(cafe['latitude'], cafe['longitude']),
        width: 80,
        height: 45,
        child: GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
        ],
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
                    initialZoom: 14.0,
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

          // ARAMA BÖLÜMÜ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
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
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.deepOrange,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _searchResults.isEmpty
                            ? const Center(child: Text("Kullanıcı bulunamadı."))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                  return ListTile(
                                    title: Text(user['username'] ?? "İsimsiz"),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserProfileScreen(
                                          targetUserId: user['id'],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. DÜZELTİLMİŞ ALT KARTLAR ALANI
          if (_searchController.text.isEmpty && _kafeler.isNotEmpty)
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
                      _updateMarkers();
                    });
                    _mapController.move(
                      LatLng(
                        _kafeler[index]['latitude'],
                        _kafeler[index]['longitude'],
                      ),
                      15.0,
                    );
                  },
                  itemBuilder: (context, index) =>
                      _buildCafeCard(_kafeler[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 3. DÜZELTİLMİŞ KAFE KARTI: cafe_postlar tablosundan gelen verileri kullanır
  Widget _buildCafeCard(dynamic cafeData) {
    // cafe_postlar tablosundan gelen listeyi alıyoruz
    final List<dynamic> postlar = cafeData['cafe_postlar'] ?? [];

    // Sadece foto_url'leri ayıklıyoruz
    final List<String> fotograflar = postlar
        .where((p) => p['foto_url'] != null)
        .map((p) => p['foto_url'].toString())
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: Post Fotoğrafları
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: fotograflar.isNotEmpty
                      ? PageView.builder(
                          itemCount: fotograflar.length,
                          itemBuilder: (context, i) {
                            return Image.network(
                              fotograflar[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[100],
                                    child: const Icon(Icons.broken_image),
                                  ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                          ),
                        ),
                ),
                if (fotograflar.length > 1)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.layers,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Alt Kısım: İsim ve Post Başlığı
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafeData['kafe_adi'] ?? "Bilinmeyen Mekan",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Açıklama olarak ilk postun başlığını basıyoruz
                    Text(
                      postlar.isNotEmpty
                          ? (postlar[0]['baslik'] ?? "Harika bir manzara!")
                          : "Henüz paylaşım yok.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Center(
                        child: Text(
                          "Detayları Gör",
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(10);
    setState(() => _searchResults = List<Map<String, dynamic>>.from(results));
  }
}
