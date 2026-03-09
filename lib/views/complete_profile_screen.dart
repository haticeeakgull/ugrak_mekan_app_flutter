import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _hasChanges = false; // Değişiklik kontrolü için
  File? _imageFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Dinleme: Herhangi bir field değişirse butonu güncelle
    _usernameController.addListener(_onFieldChanged);
    _fullNameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  // Değişiklik algılandığında state'i güncelle
  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
      _fetchProfileData(user.id);
    }
  }

  Future<void> _fetchProfileData(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        setState(() {
          _usernameController.text = data['username'] ?? "";
          _fullNameController.text = data['full_name'] ?? "";
          _bioController.text = data['bio'] ?? "";
          _avatarUrl = data['avatar_url'];
          // Veriler ilk yüklendiğinde "değişiklik yok" sayıyoruz
          _hasChanges = false;
        });
      }
    } catch (e) {
      print("Veri çekme hatası: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _hasChanges = true; // Fotoğraf seçildiğinde buton güncellensin
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<String> updatedItems = []; // Kullanıcıya raporlamak için

    try {
      String? finalAvatarUrl = _avatarUrl;

      // 1. Fotoğraf Yükleme
      if (_imageFile != null) {
        final userId = user.id;
        final fileExt = _imageFile!.path.split('.').last;
        final fileName =
            '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('avatars')
            .upload(
              fileName,
              _imageFile!,
              fileOptions: const FileOptions(upsert: true),
            );

        finalAvatarUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(fileName);
        updatedItems.add("Profil fotoğrafı");
      }

      // 2. Profil Bilgileri
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': finalAvatarUrl,
      });
      updatedItems.add("Profil bilgileri");

      // 3. E-posta Güncelleme
      bool emailChanged = false;
      if (_emailController.text.trim() != user.email) {
        await _supabase.auth.updateUser(
          UserAttributes(email: _emailController.text.trim()),
        );
        emailChanged = true;
        updatedItems.add("E-posta adresi");
      }

      if (mounted) {
        // Rapor Mesajı Oluşturma
        String report = "${updatedItems.join(', ')} başarıyla güncellendi.";
        if (emailChanged) report += "\nLütfen yeni e-postanızı onaylayın.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() => _hasChanges = false); // Butonu eski haline getir

        // Eğer her şey tamamsa ve kullanıcı ilk defa gelmiyorsa yönlendirilebilir
        // Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Profilini Şekillendir",
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- PROFİL FOTOĞRAFI ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.white,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null)
                              as ImageProvider?,
                    child: _imageFile == null && _avatarUrl == null
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildCustomField(
              controller: _fullNameController,
              label: "Ad Soyad",
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            _buildCustomField(
              controller: _usernameController,
              label: "Kullanıcı Adı",
              icon: Icons.alternate_email,
            ),
            const SizedBox(height: 16),
            _buildCustomField(
              controller: _bioController,
              label: "Bio (Kısaca sen)",
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Hesap Ayarları",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            _buildCustomField(
              controller: _emailController,
              label: "E-posta Adresi",
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 40),

            // --- DİNAMİK BUTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasChanges
                      ? Colors.blueAccent
                      : Colors.deepOrange, // Değişiklik varsa renk değişsin
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _hasChanges ? "Bilgileri Güncelle" : "Hadi Başlayalım!",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: _hasChanges ? Colors.blueAccent : Colors.deepOrange,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}
