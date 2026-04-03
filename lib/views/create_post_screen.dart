import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';

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
  final List<dynamic> _mediaList = [];
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
              orElse: () => {'kafe_adi': 'Mekan Seçilmedi'},
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
        final File originalFile = File(xFile.path);
        if (await originalFile.exists()) {
          File? cropped = await _cropImage(originalFile);
          if (cropped != null && mounted) {
            setState(() => _mediaList.add(cropped));
          }
        }
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    // İşletim sisteminin dosyayı kilitlemesini önlemek için kısa bir gecikme
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Fotoğrafı Düzenle',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Düzenle'),
        ],
      );

      if (croppedFile != null) {
        final file = File(croppedFile.path);
        if (await file.exists()) return file;
      }
    } catch (e) {
      debugPrint("Kırpma hatası: $e");
    }
    return null;
  }

  Future<void> _uploadPost() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar("Lütfen önce giriş yapın.");
      return;
    }

    if (_selectedCafeId == null || _mediaList.isEmpty) {
      _showSnackBar("Mekan seçmeyi ve fotoğraf eklemeyi unutma!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> finalUrls = [];
      // Listeyi kopyalıyoruz ki döngü sırasında değişikliklerden etkilenmesin
      final List<dynamic> uploadQueue = List.from(_mediaList);

      for (int i = 0; i < uploadQueue.length; i++) {
        var item = uploadQueue[i];

        if (item is String) {
          finalUrls.add(item);
        } else if (item is File) {
          if (!await item.exists()) continue;

          // Eşsiz dosya ismi: zaman_userid_index
          final String fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${user.id}_$i.jpg';
          final String path = 'cafe_photos/${user.id}/$fileName';

          try {
            await _supabase.storage.from('posts').upload(path, item);
            final String publicUrl = _supabase.storage
                .from('posts')
                .getPublicUrl(path);
            finalUrls.add(publicUrl);
            debugPrint("Yüklendi: $publicUrl");
          } catch (storageError) {
            debugPrint("Storage hatası ($i): $storageError");
            // Bir fotoğraf başarısız olursa diğerleri devam etsin
          }
        }
      }

      final Map<String, dynamic> data = {
        'cafe_id': _selectedCafeId,
        'user_id': user.id,
        'baslik': _titleController.text.trim(),
        'icerik': _contentController.text.trim(),
        'foto_url': finalUrls.isNotEmpty ? finalUrls.first : null,
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
      debugPrint("Genel hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI METODLARI ---

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Postu Düzenle" : (_selectedCafeName ?? "Yeni Öneri"),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditMode) _buildCafeSelector(),
                  _buildSectionTitle("Fotoğraflar", Icons.photo_camera_back),
                  const SizedBox(height: 12),
                  _buildPhotoList(),
                  const SizedBox(height: 25),
                  _buildTextFields(),
                  const Divider(height: 40, thickness: 1),
                  _buildSectionTitle("Mekan Analizi", Icons.analytics_outlined),
                  const SizedBox(height: 20),
                  _buildSlider(
                    "Kalabalık",
                    Icons.people_outline,
                    _kalabalik,
                    (v) => setState(() => _kalabalik = v),
                  ),
                  _buildSlider(
                    "Ses Düzeyi",
                    Icons.volume_down_outlined,
                    _ses,
                    (v) => setState(() => _ses = v),
                  ),
                  _buildSlider(
                    "Priz Sayısı",
                    Icons.power_outlined,
                    _priz,
                    (v) => setState(() => _priz = v),
                  ),
                  _buildSlider(
                    "İnternet",
                    Icons.wifi_outlined,
                    _internet,
                    (v) => setState(() => _internet = v),
                  ),
                  _buildSlider(
                    "Çalışma",
                    Icons.laptop_mac_outlined,
                    _calisma,
                    (v) => setState(() => _calisma = v),
                  ),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Vibe Etiketleri", Icons.mood_outlined),
                  const SizedBox(height: 12),
                  _buildVibeChips(),
                  const SizedBox(height: 40),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoList() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaList.length + 1,
        itemBuilder: (context, index) {
          if (index == _mediaList.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
            );
          }
          final item = _mediaList[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item is File
                      ? Image.file(
                          item,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 110,
                        )
                      : Image.network(
                          item,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 110,
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _mediaList.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
            hintText: 'Mekan hakkında kısa bir başlık...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            prefixIcon: const Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _contentController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Deneyimin',
            hintText: 'Ortam nasıldı? Kahveleri nasıl? Çalışmak için uygun mu?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                "${value.toInt()}/5",
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildVibeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: _availableVibes.map((vibe) {
        final isSelected = _selectedVibes.contains(vibe);
        return FilterChip(
          label: Text(
            vibe,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.black87,
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
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: Text(
          _isEditMode ? "GÜNCELLEMEYİ KAYDET" : "ŞİMDİ PAYLAŞ",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCafeSelector() {
    return GestureDetector(
      onTap: _showCafePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCafeName ?? "Hangi mekandasın?",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: _selectedCafeName == null
                      ? Colors.orange[800]
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

  void _showCafePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              TextField(
                decoration: InputDecoration(
                  hintText: "Mekan ismiyle ara...",
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
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: _filteredCafes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final cafe = _filteredCafes[index];
                    return ListTile(
                      title: Text(
                        cafe['kafe_adi'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(
                          Icons.coffee,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(m),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
    ),
  );
}
