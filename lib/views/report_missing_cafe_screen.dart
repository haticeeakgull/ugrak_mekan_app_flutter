import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/missing_cafe_service.dart';
import '../widgets/explore/map_location_picker.dart';

/// Eksik Kafe Bildirimi - Tam Ekran Modern Form
class ReportMissingCafeScreen extends StatefulWidget {
  const ReportMissingCafeScreen({super.key});

  @override
  State<ReportMissingCafeScreen> createState() => _ReportMissingCafeScreenState();
}

class _ReportMissingCafeScreenState extends State<ReportMissingCafeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cafeNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _missingCafeService = MissingCafeService();

  LatLng? _selectedLocation;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color lightGreen = const Color(0xFF9FCB98);
  final Color vanilla = const Color(0xFFFAF8F3);

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _cafeNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectLocationOnMap() async {
    final selectedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapLocationPicker(
          initialLocation: _userLocation ?? const LatLng(39.9334, 32.8597),
          onLocationSelected: (location) {
            Navigator.pop(context, location);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    if (selectedLocation != null && mounted) {
      setState(() => _selectedLocation = selectedLocation);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_userLocation != null) {
      setState(() => _selectedLocation = _userLocation);
    } else {
      _showSnackBar('❌ Konum bilgisi alınamadı', isError: true);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      _showSnackBar('❌ Lütfen haritada konum seçin', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _missingCafeService.reportMissingCafe(
        cafeName: _cafeNameController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        additionalNotes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Bildiriminiz kaydedildi. Teşekkürler!'),
            backgroundColor: deepGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('❌ Hata: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : deepGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vanilla,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: deepGreen,
        elevation: 0,
        title: Text(
          'Eksik Kafe Bildir',
          style: TextStyle(fontWeight: FontWeight.w900, color: deepGreen),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: deepGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: midGreen.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: deepGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt,
                        color: deepGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bilmediğimiz bir kafe mi var?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: deepGreen,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bildirdiğin kafeler incelendikten sonra uygulamaya eklenecek.',
                      style: TextStyle(
                        fontSize: 14,
                        color: midGreen,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Alanları
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kafe Adı
                    _buildSectionTitle('Kafe Adı', Icons.local_cafe),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cafeNameController,
                      decoration: InputDecoration(
                        hintText: 'Örn: Kahve Dükkanı',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                        prefixIcon: Icon(Icons.store, color: deepGreen),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kafe adı gerekli';
                        }
                        if (value.trim().length < 3) {
                          return 'En az 3 karakter olmalı';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Konum
                    _buildSectionTitle('Konum', Icons.location_on),
                    const SizedBox(height: 12),
                    
                    if (_selectedLocation != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: deepGreen, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: deepGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: deepGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Konum Seçildi',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: deepGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  color: Colors.grey,
                                  onPressed: () {
                                    setState(() => _selectedLocation = null);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _selectLocationOnMap,
                              icon: const Icon(Icons.edit_location, size: 18),
                              label: const Text('Konumu Değiştir'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: deepGreen,
                                side: BorderSide(color: deepGreen),
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 20),
                            label: Text(
                              _isLoadingLocation ? 'Konum Alınıyor...' : 'Mevcut Konumum',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: deepGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _selectLocationOnMap,
                            icon: const Icon(Icons.map, size: 20),
                            label: const Text('Haritada Seç'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: deepGreen,
                              side: BorderSide(color: deepGreen, width: 2),
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Ek Notlar
                    _buildSectionTitle('Ek Notlar (Opsiyonel)', Icons.note_alt),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Adres, özellikler veya diğer bilgiler...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Gönder Butonu
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Bildirimi Gönder',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(height: 32),
                  ],
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
        Icon(icon, color: deepGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: deepGreen,
          ),
        ),
      ],
    );
  }
}
