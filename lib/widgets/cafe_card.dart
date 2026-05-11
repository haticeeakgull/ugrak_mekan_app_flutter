import 'package:flutter/material.dart';
import '../models/cafe_model.dart';
import 'package:ugrak_mekan_app/widgets/cafe_detail_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeCard extends StatefulWidget {
  final Cafe cafe;
  final String? searchQuery;
  final Map<String, double>? matchScores;

  const CafeCard({
    super.key,
    required this.cafe,
    this.searchQuery,
    this.matchScores,
  });

  @override
  State<CafeCard> createState() => _CafeCardState();
}

class _CafeCardState extends State<CafeCard> {
  String? _postImageUrl;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _fetchCafeImage();
  }

  /// Kafenin ilk post fotoğrafını getir
  /// Hibrit Fotoğraf Getirme: Önce kullanıcı postlarına, yoksa Google fotoğraflarına bakar.
  Future<void> _fetchCafeImage() async {
    if (!mounted) return;
    
    try {
      final supabase = Supabase.instance.client;

      // 1. ADIM: cafe_postlar (Öncelik)
      final postResponse = await supabase
          .from('cafe_postlar')
          .select('foto_url')
          .eq('cafe_id', widget.cafe.id)
          .limit(1); // maybeSingle yerine liste olarak isteyelim

      if (postResponse != null && postResponse.isNotEmpty) {
        if (mounted) {
          setState(() {
            _postImageUrl = postResponse.first['foto_url'];
            _isLoadingImage = false;
          });
        }
        return;
      }

      // 2. ADIM: cafe_fotograflar (Yedek)
      // .select() içine sadece 'foto_url' yazalım, bazen tüm sütunları çekmek RLS'e takılabilir
      final googlePhotoResponse = await supabase
          .from('cafe_fotograflar')
          .select('foto_url')
          .eq('cafe_id', widget.cafe.id);

      // DEBUG LOGLARI
      debugPrint("DEBUG: ${widget.cafe.kafeAdi} Sorgulanıyor...");
      debugPrint("Gelen Yanıt: $googlePhotoResponse");

      if (mounted) {
        setState(() {
          // Liste boş değilse ilk fotoğrafı al, boşsa null bırak
          _postImageUrl = (googlePhotoResponse != null && googlePhotoResponse.isNotEmpty)
              ? googlePhotoResponse.first['foto_url']
              : null;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint('FOTOĞRAF ÇEKME HATASI (${widget.cafe.kafeAdi}): $e');
      if (mounted) {
        setState(() {
          _postImageUrl = null;
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMatch =
        widget.matchScores != null && widget.matchScores!.isNotEmpty;
    final avgMatch = hasMatch
        ? (widget.matchScores!.values.reduce((a, b) => a + b) /
                  widget.matchScores!.length *
                  100)
              .round()
        : null;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CafeDetailSheet(cafe: widget.cafe),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Sol: Resim
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: _isLoadingImage
                  ? Container(
                      width: 120,
                      height: 140,
                      color: Colors.grey[100],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : _postImageUrl != null
                  ? Image.network(
                      _postImageUrl!,
                      width: 120,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : widget.cafe.gorseller.isNotEmpty
                  ? Image.network(
                      widget.cafe.gorseller.first['foto_url'],
                      width: 120,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),

            // Sağ: Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Üst: Başlık + Uyum
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cafe.kafeAdi,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.cafe.ilceAdi,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Alt: Reason (varsa) veya Uyum yüzdesi
                    if (widget.cafe.reason != null && widget.cafe.reason!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF346739).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 12,
                              color: const Color(0xFF346739),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.cafe.reason!,
                                style: const TextStyle(
                                  color: const Color(0xFF346739),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (avgMatch != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF346739).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '%$avgMatch uyumlu',
                          style: const TextStyle(
                            color: const Color(0xFF346739),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Sağ: Ok
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 120,
      height: 140,
      color: Colors.grey[150],
      child: Icon(Icons.local_cafe, size: 35, color: Colors.grey[400]),
    );
  }
}
