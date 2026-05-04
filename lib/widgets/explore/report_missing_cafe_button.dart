import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/missing_cafe_service.dart';
import 'map_location_picker.dart';

/// Eksik kafe bildirimi için floating button ve dialog
class ReportMissingCafeButton extends StatefulWidget {
  final GoogleMapController? mapController;
  final LatLng? userLocation;

  const ReportMissingCafeButton({
    super.key,
    this.mapController,
    this.userLocation,
  });

  @override
  State<ReportMissingCafeButton> createState() =>
      _ReportMissingCafeButtonState();
}

class _ReportMissingCafeButtonState extends State<ReportMissingCafeButton> {
  final _missingCafeService = MissingCafeService();
  LatLng? _selectedLocation;

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReportMissingCafeDialog(
        mapController: widget.mapController,
        userLocation: widget.userLocation,
        onSubmit: _handleSubmit,
        preSelectedLocation: _selectedLocation,
      ),
    );
  }

  Future<void> _selectLocationOnMap() async {
    // Dialog'u kapat
    Navigator.pop(context);

    // Map location picker'ı göster
    final selectedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapLocationPicker(
          initialLocation: widget.userLocation ?? const LatLng(39.9334, 32.8597),
          onLocationSelected: (location) {
            Navigator.pop(context, location);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    // Konum seçildiyse dialog'u tekrar aç
    if (selectedLocation != null) {
      setState(() => _selectedLocation = selectedLocation);
      // Dialog'u tekrar göster
      if (mounted) {
        _showReportDialog();
      }
    }
  }

  Future<void> _handleSubmit({
    required String cafeName,
    required LatLng location,
    String? notes,
  }) async {
    try {
      await _missingCafeService.reportMissingCafe(
        cafeName: cafeName,
        latitude: location.latitude,
        longitude: location.longitude,
        additionalNotes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bildiriminiz kaydedildi. Teşekkürler!'),
            backgroundColor: Color(0xFF346739),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 100,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          onTap: _showReportDialog,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF346739), Color(0xFF79AE6F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF346739).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Eksik Kafe',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bildir',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eksik kafe bildirimi dialog'u
class _ReportMissingCafeDialog extends StatefulWidget {
  final GoogleMapController? mapController;
  final LatLng? userLocation;
  final LatLng? preSelectedLocation;
  final Function({
    required String cafeName,
    required LatLng location,
    String? notes,
  }) onSubmit;

  const _ReportMissingCafeDialog({
    this.mapController,
    this.userLocation,
    this.preSelectedLocation,
    required this.onSubmit,
  });

  @override
  State<_ReportMissingCafeDialog> createState() =>
      _ReportMissingCafeDialogState();
}

class _ReportMissingCafeDialogState extends State<_ReportMissingCafeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cafeNameController = TextEditingController();
  final _notesController = TextEditingController();

  LatLng? _selectedLocation;
  bool _isSubmitting = false;

  final Color deepGreen = const Color(0xFF346739);
  final Color midGreen = const Color(0xFF79AE6F);
  final Color vanilla = const Color(0xFFF2EDC2);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.preSelectedLocation;
  }

  @override
  void dispose() {
    _cafeNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectLocationOnMap() async {
    // Map location picker'ı göster (dialog'u kapatmadan)
    final selectedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapLocationPicker(
          initialLocation: widget.userLocation ?? const LatLng(39.9334, 32.8597),
          onLocationSelected: (location) {
            Navigator.pop(context, location);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    // Konum seçildiyse state'i güncelle (dialog açık kalacak)
    if (selectedLocation != null && mounted) {
      setState(() => _selectedLocation = selectedLocation);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (widget.userLocation != null) {
      setState(() => _selectedLocation = widget.userLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Konum bilgisi alınamadı'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Lütfen haritada konum seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        cafeName: _cafeNameController.text,
        location: _selectedLocation!,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: vanilla,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: deepGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt_outlined,
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
                            'Eksik Kafe Bildir',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: deepGreen,
                            ),
                          ),
                          Text(
                            'Bilmediğimiz bir kafe mi var?',
                            style: TextStyle(
                              fontSize: 12,
                              color: midGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Kafe Adı
                Text(
                  'Kafe Adı *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cafeNameController,
                  decoration: InputDecoration(
                    hintText: 'Örn: Kahve Dükkanı',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                const SizedBox(height: 16),

                // Konum Seçimi
                Text(
                  'Konum *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (_selectedLocation != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: deepGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: deepGreen, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: deepGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                color: deepGreen,
                                onPressed: () {
                                  setState(() => _selectedLocation = null);
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_selectedLocation == null) ...[
                        ElevatedButton.icon(
                          onPressed: _useCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Mevcut Konumum'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _selectLocationOnMap,
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Haritada Seç'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: deepGreen,
                            side: BorderSide(color: deepGreen),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notlar (Opsiyonel)
                Text(
                  'Ek Notlar (Opsiyonel)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Adres, özellikler vb. eklemek isterseniz...',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: deepGreen,
                          side: BorderSide(color: deepGreen.withOpacity(0.5)),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'İptal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Bildir',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
