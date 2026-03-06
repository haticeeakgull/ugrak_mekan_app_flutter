import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    try {
      await _supabase
          .from('profiles')
          .update({
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim(),
            'bio': _bioController.text.trim(),
          })
          .eq('id', userId);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home'); // Home'a git
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profilini Tamamla")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: "Ad Soyad"),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Kullanıcı Adı (Benzersiz)",
              ),
            ),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: "Kendinden bahset"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Kaydet ve Başla"),
            ),
          ],
        ),
      ),
    );
  }
}
