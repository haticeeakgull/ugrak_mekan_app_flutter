import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final String? cafeId; // Artık opsiyonel (?)
  final String? initialCafeName; // Başlıkta göstermek için opsiyonel

  const CreatePostScreen({super.key, this.cafeId, this.initialCafeName});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _image;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  // --- Kafe Seçimi İçin Gerekli Değişkenler ---
  String? _selectedCafeId;
  String? _selectedCafeName;
  List<Map<String, dynamic>> _allCafes = [];
  List<Map<String, dynamic>> _filteredCafes = [];

  // --- Analiz Değerleri (Slider 1-5) ---
  double _kalabalik = 3;
  double _ses = 3;
  double _priz = 3;
  double _internet = 3;
  double _calisma = 3;
  double _muzik = 3;

  final List<String> _availableVibes = [
    "Sessiz",
    "Modern",
    "Retro",
    "Canlı",
    "Evden Çalışma",
    "Loş",
    "Ferah",
    "Kitap Kafe",
    "Bahçeli",
    "Üçüncü Nesil",
    "Hızlı Servis",
  ];
  final List<String> _selectedVibes = [];

  @override
  void initState() {
    super.initState();
    _selectedCafeId = widget.cafeId;
    _selectedCafeName = widget.initialCafeName;

    // Eğer profil sayfasından geliyorsa (cafeId yoksa) veritabanından kafeleri çek
    if (_selectedCafeId == null) {
      _fetchCafes();
    }
  }

  Future<void> _fetchCafes() async {
    try {
      final data = await _supabase
          .from('ilce_isimli_kafeler')
          .select('id, kafe_adi');
      setState(() {
        _allCafes = List<Map<String, dynamic>>.from(data);
        _filteredCafes = _allCafes;
      });
    } catch (e) {
      debugPrint("Kafe listesi çekilemedi: $e");
    }
  }

  void _showCafePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Hangi Mekandasın?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Mekan ara...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      _filteredCafes = _allCafes.where((c) {
                        final name =
                            c['kafe_adi']?.toString().toLowerCase() ??
                            ""; // null ise boş string yap
                        return name.contains(val.toLowerCase());
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _filteredCafes.length,
                    itemBuilder: (context, index) {
                      final cafe = _filteredCafes[index];
                      return ListTile(
                        leading: const Icon(Icons.coffee, color: Colors.orange),
                        title: Text(cafe['kafe_adi'] ?? "İsimsiz Mekan"),
                        onTap: () {
                          setState(() {
                            _selectedCafeId = cafe['id'].toString();
                            _selectedCafeName = cafe['cafe_adi'];
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  Future<void> _uploadPost() async {
    if (_selectedCafeId == null) {
      _showSnackBar("Lütfen bir mekan seçin!");
      return;
    }
    if (_image == null ||
        _titleController.text.isEmpty ||
        _contentController.text.isEmpty) {
      _showSnackBar("Lütfen fotoğraf, başlık ve deneyiminizi ekleyin!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "Giriş yapmış kullanıcı bulunamadı!";

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'cafe_photos/${user.id}/$fileName';
      await _supabase.storage.from('posts').upload(path, _image!);
      final imageUrl = _supabase.storage.from('posts').getPublicUrl(path);

      final Map<String, dynamic> degerlendirme = {
        "kalabalik": _kalabalik.toInt(),
        "ses": _ses.toInt(),
        "priz": _priz.toInt(),
        "internet": _internet.toInt(),
        "calisma": _calisma.toInt(),
        "muzik": _muzik.toInt(),
        "secilen_vibeler": _selectedVibes,
      };

      await _supabase.from('cafe_postlar').insert({
        'cafe_id': _selectedCafeId,
        'user_id': user.id,
        'baslik': _titleController.text.trim(),
        'icerik': _contentController.text.trim(),
        'foto_url': imageUrl,
        'degerlendirme': degerlendirme,
        'paylasim_tarihi': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackBar("Paylaşımın başarıyla yüklendi! ✨", isError: false);
        Navigator.pop(context);
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

  // --- Widget Parçaları ---

  Widget _buildCafeSelector() {
    if (widget.cafeId != null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showCafePicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCafeName ?? "Mekan Seçmek İçin Tıkla",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedCafeName == null
                      ? Colors.orange
                      : Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 220,
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
                    size: 45,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Mekandan bir kare seç",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Başlık',
            hintText: 'Örn: Kadıköy\'ün en sakin köşesi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contentController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Deneyimin',
            hintText: 'Burayı neden sevdin? Kahvesi nasıl?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.notes),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String title,
    IconData icon,
    double value,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
            const Spacer(),
            Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: Colors.deepOrange,
          inactiveColor: Colors.orange.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildVibeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _availableVibes.map((vibe) {
        final isSelected = _selectedVibes.contains(vibe);
        return FilterChip(
          label: Text(
            vibe,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.deepOrange,
          checkmarkColor: Colors.white,
          onSelected: (selected) {
            setState(() {
              selected ? _selectedVibes.add(vibe) : _selectedVibes.remove(vibe);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _uploadPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Paylaş",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedCafeName ?? "Yeni Mekan Notu",
          style: const TextStyle(color: Colors.black87, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCafeSelector(),
            _buildPhotoPicker(),
            const SizedBox(height: 25),
            _buildTextFields(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(thickness: 1),
            ),
            _buildSectionTitle("Mekan Analizi", Icons.analytics_outlined),
            const SizedBox(height: 15),
            _buildSlider(
              "Kalabalık",
              Icons.groups,
              _kalabalik,
              (v) => setState(() => _kalabalik = v),
            ),
            _buildSlider(
              "Ses Düzeyi",
              Icons.volume_up,
              _ses,
              (v) => setState(() => _ses = v),
            ),
            _buildSlider(
              "Priz Sayısı",
              Icons.power,
              _priz,
              (v) => setState(() => _priz = v),
            ),
            _buildSlider(
              "İnternet Hızı",
              Icons.wifi,
              _internet,
              (v) => setState(() => _internet = v),
            ),
            _buildSlider(
              "Çalışma Uygunluğu",
              Icons.laptop,
              _calisma,
              (v) => setState(() => _calisma = v),
            ),
            _buildSlider(
              "Müzik Seviyesi",
              Icons.music_note,
              _muzik,
              (v) => setState(() => _muzik = v),
            ),
            const SizedBox(height: 25),
            _buildSectionTitle("Vibe Etiketleri", Icons.style_outlined),
            const SizedBox(height: 12),
            _buildVibeChips(),
            const SizedBox(height: 40),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
