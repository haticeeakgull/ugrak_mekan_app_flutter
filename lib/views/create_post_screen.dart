import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final String cafeId; // Hangi kafeye post atıldığını bilmemiz lazım

  const CreatePostScreen({super.key, required this.cafeId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController(); // Tablodaki 'baslik'
  final _contentController = TextEditingController(); // Tablodaki 'icerik'
  File? _image;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  // Galeriden Fotoğraf Seçme
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Boyutu biraz düşürüp hızı artıralım
    );

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  // Paylaşma Fonksiyonu
  Future<void> _uploadPost() async {
    if (_image == null ||
        _titleController.text.isEmpty ||
        _contentController.text.isEmpty) {
      _showSnackBar("Lütfen tüm alanları doldurun ve bir fotoğraf seçin!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "Giriş yapmış kullanıcı bulunamadı!";

      // 1. Fotoğrafı Storage'a Yükle (posts bucket'ı oluşturduğunu varsayıyorum)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'cafe_photos/${user.id}/$fileName';

      await _supabase.storage.from('posts').upload(path, _image!);

      // 2. Yüklenen fotoğrafın URL'ini al
      final imageUrl = _supabase.storage.from('posts').getPublicUrl(path);

      // 3. Veritabanına (cafe_postlar) kaydet
      await _supabase.from('cafe_postlar').insert({
        'cafe_id': widget.cafeId,
        'user_id': user.id,
        'baslik': _titleController.text.trim(),
        'icerik': _contentController.text.trim(),
        'foto_url': imageUrl,
        'paylasim_tarihi': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackBar("Paylaşımın başarıyla yüklendi! ✨", isError: false);
        Navigator.pop(context); // Başarılıysa geri dön
      }
    } catch (e) {
      _showSnackBar("Bir hata oluştu: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Yeni Mekan Notu",
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Fotoğraf Seçme Kutusu
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: _image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 40,
                            color: Colors.orange,
                          ),
                          Text(
                            "Mekandan bir kare seç",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık (Mekan Adı veya Kısa Başlık)
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Başlık',
                hintText: 'Örn: Kadıköy\'ün en sakin köşesi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // İçerik (Deneyim/Yorum)
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Deneyimin',
                hintText: 'Burayı neden sevdin? Kahvesi nasıl?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Paylaş Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _uploadPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Paylaş",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
