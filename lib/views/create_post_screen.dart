import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final String? cafeId;
  final String? initialCafeName;
  final Map<String, dynamic>? initialPostData;

  const CreatePostScreen({
    super.key,
    this.cafeId,
    this.initialCafeName,
    this.initialPostData,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<dynamic> _mediaList = []; // Hata uyarısı için final yapıldı
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  String? _selectedCafeId;
  String? _selectedCafeName;
  List<Map<String, dynamic>> _allCafes = [];
  List<Map<String, dynamic>> _filteredCafes = [];

  bool get _isEditMode => widget.initialPostData != null;

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
    _fetchCafes();

    if (_isEditMode) {
      final post = widget.initialPostData!;
      _titleController.text = post['baslik'] ?? '';
      _contentController.text = post['icerik'] ?? '';
      _selectedCafeId = post['cafe_id']?.toString();

      final deg = post['degerlendirme'] ?? {};
      _kalabalik = (deg['kalabalik'] ?? 3).toDouble();
      _ses = (deg['ses'] ?? 3).toDouble();
      _priz = (deg['priz'] ?? 3).toDouble();
      _internet = (deg['internet'] ?? 3).toDouble();
      _calisma = (deg['calisma'] ?? 3).toDouble();
      _muzik = (deg['muzik'] ?? 3).toDouble();

      if (deg['secilen_vibeler'] != null) {
        _selectedVibes.addAll(List<String>.from(deg['secilen_vibeler']));
      }
      if (post['foto_listesi'] != null) {
        _mediaList.addAll(List<String>.from(post['foto_listesi']));
      }
    } else {
      _selectedCafeId = widget.cafeId;
      _selectedCafeName = widget.initialCafeName;
    }
  }

  Future<void> _fetchCafes() async {
    try {
      final data = await _supabase
          .from('ilce_isimli_kafeler')
          .select('id, kafe_adi');
      if (mounted) {
        setState(() {
          _allCafes = List<Map<String, dynamic>>.from(data);
          _filteredCafes = _allCafes;
          if (_isEditMode && _selectedCafeName == null) {
            _selectedCafeName = _allCafes.firstWhere(
              (c) => c['id'].toString() == _selectedCafeId,
              orElse: () => {'kafe_adi': 'Mekan'},
            )['kafe_adi'];
          }
        });
      }
    } catch (e) {
      debugPrint("Kafe listesi çekilemedi: $e");
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    if (pickedFiles.isNotEmpty) {
      for (var xFile in pickedFiles) {
        File? cropped = await _cropImage(File(xFile.path));
        if (cropped != null) setState(() => _mediaList.add(cropped));
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    // HATA DÜZELTMESİ: ImageCropper'da aspectRatioPresets uiSettings içine taşındı
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Düzenle',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            // Buraya taşındı
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
          ],
        ),
        IOSUiSettings(
          title: 'Düzenle',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _uploadPost() async {
    if (_selectedCafeId == null || _mediaList.isEmpty) {
      _showSnackBar("Mekan seçmeyi ve fotoğraf eklemeyi unutma!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      List<String> finalUrls = [];

      for (var item in _mediaList) {
        if (item is String) {
          finalUrls.add(item);
        } else if (item is File) {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_mediaList.indexOf(item)}.jpg';
          final path = 'cafe_photos/${user!.id}/$fileName';
          await _supabase.storage.from('posts').upload(path, item);
          finalUrls.add(_supabase.storage.from('posts').getPublicUrl(path));
        }
      }

      final data = {
        'cafe_id': _selectedCafeId,
        'user_id': user!.id,
        'baslik': _titleController.text.trim(),
        'icerik': _contentController.text.trim(),
        'foto_url': finalUrls.first,
        'foto_listesi': finalUrls,
        'degerlendirme': {
          "kalabalik": _kalabalik.toInt(),
          "ses": _ses.toInt(),
          "priz": _priz.toInt(),
          "internet": _internet.toInt(),
          "calisma": _calisma.toInt(),
          "muzik": _muzik.toInt(),
          "secilen_vibeler": _selectedVibes,
        },
      };

      if (_isEditMode) {
        await _supabase
            .from('cafe_postlar')
            .update(data)
            .eq('id', widget.initialPostData!['id']);
        if (mounted) Navigator.pop(context, data);
      } else {
        data['paylasim_tarihi'] = DateTime.now().toIso8601String();
        await _supabase.from('cafe_postlar').insert(data);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar("Bir sorun oluştu: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Postu Düzenle" : (_selectedCafeName ?? "Yeni Öneri"),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditMode) _buildCafeSelector(),
                  _buildSectionTitle(
                    "Fotoğraflar",
                    Icons.photo_library_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoList(),
                  const SizedBox(height: 25),
                  _buildTextFields(),
                  const Divider(height: 40),
                  // HATA DÜZELTMESİ: edit_rating_rounded yerine star_rate kullanıldı
                  _buildSectionTitle("Mekan Analizi", Icons.star_rate_rounded),
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
                    "İnternet",
                    Icons.wifi,
                    _internet,
                    (v) => setState(() => _internet = v),
                  ),
                  _buildSlider(
                    "Çalışma",
                    Icons.laptop,
                    _calisma,
                    (v) => setState(() => _calisma = v),
                  ),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Vibe Etiketleri", Icons.style_outlined),
                  const SizedBox(height: 12),
                  _buildVibeChips(),
                  const SizedBox(height: 40),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPhotoList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaList.length + 1,
        itemBuilder: (context, index) {
          if (index == _mediaList.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  // HATA DÜZELTMESİ: withOpacity yerine withValues kullanıldı
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.orange),
              ),
            );
          }
          final item = _mediaList[index];
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: item is File
                      ? Image.file(item, fit: BoxFit.cover)
                      : Image.network(item, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 15,
                top: 5,
                child: GestureDetector(
                  onTap: () => setState(() => _mediaList.removeAt(index)),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contentController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Deneyimlerini anlat...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            Text(title),
            const Spacer(),
            Text(
              "${value.toInt()}/5",
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
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildVibeChips() {
    return Wrap(
      spacing: 8,
      children: _availableVibes.map((vibe) {
        final isSelected = _selectedVibes.contains(vibe);
        return FilterChip(
          label: Text(
            vibe,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 12,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.deepOrange,
          checkmarkColor: Colors.white,
          onSelected: (val) => setState(
            () => val ? _selectedVibes.add(vibe) : _selectedVibes.remove(vibe),
          ),
        );
      }).toList(),
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
        ),
        child: Text(
          _isEditMode ? "GÜNCELLE" : "PAYLAŞ",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCafeSelector() {
    return GestureDetector(
      onTap: _showCafePicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCafeName ?? "Hangi Mekandasın?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedCafeName == null
                      ? Colors.orange
                      : Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  void _showCafePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
                onChanged: (val) => setState(() {
                  _filteredCafes = _allCafes
                      .where(
                        (c) => c['kafe_adi'].toString().toLowerCase().contains(
                          val.toLowerCase(),
                        ),
                      )
                      .toList();
                }),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _filteredCafes.length,
                  itemBuilder: (context, index) {
                    final cafe = _filteredCafes[index];
                    return ListTile(
                      leading: const Icon(Icons.coffee, color: Colors.orange),
                      title: Text(cafe['kafe_adi']),
                      onTap: () {
                        setState(() {
                          _selectedCafeId = cafe['id'].toString();
                          _selectedCafeName = cafe['kafe_adi'];
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
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
  );
}
