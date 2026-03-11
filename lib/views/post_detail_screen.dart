import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allPosts;
  final int initialIndex;

  const PostDetailScreen({
    super.key,
    required this.allPosts,
    required this.initialIndex,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PageController _pageController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Öneriler",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical, // Dikey kaydırma (Reels tarzı)
        itemCount: widget.allPosts.length,
        itemBuilder: (context, index) {
          final post = widget.allPosts[index];

          // --- NORMALİZE EDİLMİŞ VERİ OKUMA ---
          // 'profiles' tablosundan gelen iç içe geçmiş (nested) veriyi okuyoruz
          final String kullaniciAdi = post['profiles'] != null
              ? (post['profiles']['username'] ?? 'Bilinmeyen Kullanıcı')
              : 'Anonim';

          final String icerikMetni = post['icerik'] ?? 'İçerik belirtilmemiş.';
          final String baslik = post['baslik'] ?? 'Başlıksız';
          final String fotoUrl = post['foto_url'] ?? '';

          return Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Kullanıcı Bilgisi (Profil ismi artık profiles tablosundan geliyor)
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepOrange.shade50,
                          child: Text(
                            kullaniciAdi.isNotEmpty
                                ? kullaniciAdi[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          kullaniciAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Görsel
                  if (fotoUrl.isNotEmpty)
                    Image.network(
                      fotoUrl,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.5,
                      fit: BoxFit.cover,
                      // Hata durumunda boş kalmasın diye bir placeholder
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),

                  // 3. Etkileşim Barı
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () {
                            // TODO: Beğeni fonksiyonunu ApiService üzerinden çağırabilirsin
                          },
                        ),
                        Text("${post['begeni_sayisi'] ?? 0} beğeni"),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          onPressed: () {
                            // TODO: Kaydetme fonksiyonu
                          },
                        ),
                      ],
                    ),
                  ),

                  // 4. Metin İçeriği
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baslik,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          icerikMetni,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(
                          height: 100,
                        ), // Sayfa sonu dikişi için boşluk
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
