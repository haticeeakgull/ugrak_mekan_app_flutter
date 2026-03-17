import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart'; // Başkasının profilini açmak için

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Kullanıcı Arama Fonksiyonu
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await supabase
          .from('profiles') // Senin tablo adın
          .select()
          .ilike('username', '%$query%') // Kullanıcı adına göre filtrele
          .limit(15);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(results);
      });
    } catch (e) {
      print("Arama hatası: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. KATMAN: HARİTA (Arka Plan)
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 100, color: Colors.grey),
                  Text(
                    "Harita Modülü Buraya Gelecek",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. KATMAN: ARAMA ÇUBUĞU (Üstte Sabit)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Material(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(30),
                    child: TextField(
                      controller: _searchController,
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
                                onPressed: () {
                                  _searchController.clear();
                                  _searchUsers("");
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  // 3. KATMAN: ARAMA SONUÇLARI (Sadece yazı yazılırsa görünür)
                  if (_searchController.text.isNotEmpty)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : _searchResults.isEmpty
                            ? const Center(child: Text("Kullanıcı bulunamadı."))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.deepOrange,
                                      child: Text(
                                        user['username'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    title: Text(user['username'] ?? "İsimsiz"),
                                    subtitle: Text(user['full_name'] ?? ""),
                                    onTap: () {
                                      // Tıklanan kullanıcının profiline git
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileScreen(
                                            targetUserId:
                                                user['id'], // Dışarıdan ID gönderiyoruz
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
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
}
