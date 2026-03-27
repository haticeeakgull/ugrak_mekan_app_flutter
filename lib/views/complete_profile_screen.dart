import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Yeni import

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
  bool _hasChanges = false;
  bool _isPrivate = false;
  File? _imageFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _usernameController.addListener(_onFieldChanged);
    _fullNameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

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
          _isPrivate = data['is_private'] ?? false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    }
  }

  // --- YENİ: GÖRÜNTÜ KIRPMA FONKSİYONU ---
  Future<void> _cropImage(String filePath) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: filePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Kare oran
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Fotoğrafı Düzenle',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Fotoğrafı Düzenle',
            doneButtonTitle: 'Bitti',
            cancelButtonTitle: 'Vazgeç',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _imageFile = File(croppedFile.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint("Kırpma hatası: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Kırpma olacağı için kaliteyi biraz yüksek tuttuk
    );

    if (image != null) {
      await _cropImage(image.path); // Seçilen resmi kırpmaya gönder
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<String> updatedItems = [];

    try {
      String? finalAvatarUrl = _avatarUrl;

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

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': finalAvatarUrl,
        'is_private': _isPrivate,
      });
      updatedItems.add("Profil bilgileri");

      if (_emailController.text.trim() != user.email) {
        await _supabase.auth.updateUser(
          UserAttributes(email: _emailController.text.trim()),
        );
        updatedItems.add("E-posta adresi (onay bekliyor)");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${updatedItems.join(', ')} güncellendi."),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _hasChanges = false);
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
    final Color themeColor = _hasChanges
        ? Colors.blueAccent
        : Colors.deepOrange;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Profil Ayarları",
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
                        decoration: BoxDecoration(
                          color: themeColor,
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
              themeColor: themeColor,
            ),
            const SizedBox(height: 16),
            _buildCustomField(
              controller: _usernameController,
              label: "Kullanıcı Adı",
              icon: Icons.alternate_email,
              themeColor: themeColor,
            ),
            const SizedBox(height: 16),
            _buildCustomField(
              controller: _bioController,
              label: "Bio (Kısaca sen)",
              icon: Icons.notes_rounded,
              maxLines: 3,
              themeColor: themeColor,
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SwitchListTile(
                title: const Text(
                  "Gizli Hesap",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  "İçeriklerini sadece takipçilerin görebilir.",
                ),
                value: _isPrivate,
                activeColor: Colors.blueAccent,
                secondary: Icon(
                  _isPrivate ? Icons.lock_outline : Icons.lock_open,
                  color: themeColor,
                ),
                onChanged: (bool value) {
                  setState(() {
                    _isPrivate = value;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildCustomField(
              controller: _emailController,
              label: "E-posta Adresi",
              icon: Icons.email_outlined,
              themeColor: themeColor,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _hasChanges ? "Bilgileri Güncelle" : "Kaydet",
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
    required Color themeColor,
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
          prefixIcon: Icon(icon, color: themeColor),
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
