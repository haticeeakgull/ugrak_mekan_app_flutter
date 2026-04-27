import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import "package:ugrak_mekan_app/widgets/cafe_detail_sheet.dart";
import 'package:ugrak_mekan_app/models/cafe_model.dart';
import 'package:ugrak_mekan_app/services/collection_service.dart';

const Color _deepGreen = Color(0xFF346739);
const Color _midGreen = Color(0xFF79AE6F);
const Color _vanilla = Color(0xFFF2EDC2);

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final String collectionName;
  final String? ownerId; // Koleksiyon sahibinin ID'si

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
    this.ownerId,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final CollectionService _collectionService = CollectionService();
  bool _isOwner = false;
  bool _isSaved = false;
  bool _isCheckingSaved = true;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
    _checkIfSaved();
  }

  void _checkOwnership() {
    final currentUserId = supabase.auth.currentUser?.id;
    _isOwner = currentUserId != null && currentUserId == widget.ownerId;
  }

  Future<void> _checkIfSaved() async {
    if (_isOwner) {
      // Kendi koleksiyonunu kaydetmeye gerek yok
      setState(() => _isCheckingSaved = false);
      return;
    }

    try {
      final isSaved = await _collectionService.isCollectionSaved(widget.collectionId);
      if (mounted) {
        setState(() {
          _isSaved = isSaved;
          _isCheckingSaved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingSaved = false);
      }
    }
  }

  Future<void> _toggleSave() async {
    try {
      if (_isSaved) {
        await _collectionService.unsaveCollection(widget.collectionId);
        if (mounted) {
          setState(() => _isSaved = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Koleksiyon kayıtlardan kaldırıldı'),
              backgroundColor: _deepGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await _collectionService.saveCollection(widget.collectionId);
        if (mounted) {
          setState(() => _isSaved = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Koleksiyon kaydedildi! ✨'),
              backgroundColor: _deepGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCollectionItems() async {
    try {
      final response = await supabase
          .from('koleksiyon_ogeleri')
          .select('''
            id,
            cafe_id,
            ilce_isimli_kafeler (
              id,
              kafe_adi,
              il_adi,
              ilce_adi,
              semt_adi
            )
          ''')
          .eq('koleksiyon_id', widget.collectionId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
      return [];
    }
  }

  Future<void> _removeFromCollection(dynamic itemId) async {
    try {
      await supabase.from('koleksiyon_ogeleri').delete().eq('id', itemId);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mekan koleksiyondan kaldırıldı'),
            backgroundColor: _deepGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Kaldırma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.collectionName,
          style: const TextStyle(
            color: _deepGreen,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _deepGreen),
        actions: [
          // Kaydet butonu (sadece başkasının koleksiyonunda)
          if (!_isOwner && !_isCheckingSaved)
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _deepGreen,
              ),
              onPressed: _toggleSave,
              tooltip: _isSaved ? 'Kayıtlardan Kaldır' : 'Kaydet',
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCollectionItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _deepGreen),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _vanilla.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      size: 50,
                      color: _deepGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Koleksiyon Boş',
                    style: TextStyle(
                      color: _deepGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Henüz hiç mekan eklenmemiş',
                    style: TextStyle(
                      color: _midGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final cafe = item['ilce_isimli_kafeler'];

              if (cafe == null) return const SizedBox.shrink();

              final String cafeName = cafe['kafe_adi'] ?? 'İsimsiz Mekan';
              final String? ilAdi = cafe['il_adi'];
              final String? ilceAdi = cafe['ilce_adi'];
              final String? semtAdi = cafe['semt_adi'];

              String location = '';
              if (semtAdi != null) location = semtAdi;
              else if (ilceAdi != null) location = ilceAdi;
              else if (ilAdi != null) location = ilAdi;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    final hamKafeVerisi = item['ilce_isimli_kafeler'];
                    if (hamKafeVerisi != null) {
                      final kafeObjesi = Cafe.fromJson(hamKafeVerisi);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CafeDetailSheet(cafe: kafeObjesi),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _midGreen.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _deepGreen.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // İkon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _vanilla,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.coffee_rounded,
                              color: _deepGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Metin
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cafeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _deepGreen,
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 13,
                                        color: _midGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _midGreen,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Sil butonu - sadece koleksiyon sahibine göster
                          if (_isOwner)
                            GestureDetector(
                              onTap: () => _showRemoveDialog(item['id']),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRemoveDialog(dynamic itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _vanilla,
        title: const Text(
          'Mekanı Kaldır',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _deepGreen,
          ),
        ),
        content: Text(
          'Bu mekanı koleksiyondan kaldırmak istediğine emin misin?',
          style: TextStyle(
            color: _deepGreen.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Vazgeç',
              style: TextStyle(
                color: _midGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeFromCollection(itemId);
            },
            child: const Text(
              'Kaldır',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
