import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';

/// Native Advanced reklam widget'ı - Post Card tasarımında
/// Discovery Sheet'teki postlar arasında gösterilir
class NativeAdPostWidget extends StatefulWidget {
  const NativeAdPostWidget({super.key});

  @override
  State<NativeAdPostWidget> createState() => _NativeAdPostWidgetState();
}

class _NativeAdPostWidgetState extends State<NativeAdPostWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 NativeAdPostWidget initState çağrıldı');
    debugPrint('📱 Debug mode: $kDebugMode');
    debugPrint('🆔 Kullanılan Native ID: ${AdHelper.nativeAdUnitId}');
    _loadAd();
  }

  void _loadAd() {
    debugPrint('📲 Native post reklam yükleniyor...');

    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      factoryId: 'postCardStyle', // Platform-specific factory ID
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native post reklam başarıyla yüklendi!');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _errorMessage = null;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ Native post reklam yüklenemedi!');
          debugPrint('   Hata mesajı: ${err.message}');
          debugPrint('   Hata kodu: ${err.code}');

          if (mounted) {
            setState(() {
              _errorMessage = 'Kod ${err.code}: ${err.message}';
            });
          }

          ad.dispose();
        },
        onAdOpened: (ad) {
          debugPrint('📖 Native post reklam açıldı');
        },
        onAdClosed: (ad) {
          debugPrint('📕 Native post reklam kapandı');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ Native post reklam gösterildi');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    debugPrint('🗑️ NativeAdPostWidget dispose ediliyor');
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reklam yüklendiyse göster - Post card boyutunda
    if (_isLoaded && _nativeAd != null) {
      return Container(
        height: 480,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.orange.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Native Ad Widget
              AdWidget(ad: _nativeAd!),
              
              // "Reklam" badge - üst sol köşede
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sponsorlu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Hata varsa debug modda göster
    if (_errorMessage != null && kDebugMode) {
      return Container(
        height: 480,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.red.shade300, width: 2),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Native Post Reklam Hatası',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Yükleniyor durumu - debug modda göster
    if (kDebugMode) {
      return Container(
        height: 480,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                '⏳ Native post reklam yükleniyor...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Production'da hiçbir şey gösterme
    return const SizedBox.shrink();
  }
}
