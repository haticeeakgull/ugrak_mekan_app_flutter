import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';

/// Native Advanced reklam widget'ı
/// CafeCard ve Post kartlarıyla aynı tasarımda
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 NativeAdWidget initState çağrıldı');
    debugPrint('📱 Debug mode: $kDebugMode');
    debugPrint('🆔 Kullanılan Native ID: ${AdHelper.nativeAdUnitId}');
    _loadAd();
  }

  void _loadAd() {
    debugPrint('📲 Native reklam yükleniyor...');

    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      factoryId: 'cafeCardStyle', // Platform-specific factory ID
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native reklam başarıyla yüklendi!');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _errorMessage = null;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ Native reklam yüklenemedi!');
          debugPrint('   Hata mesajı: ${err.message}');
          debugPrint('   Hata kodu: ${err.code}');
          debugPrint('   Domain: ${err.domain}');

          if (mounted) {
            setState(() {
              _errorMessage = 'Kod ${err.code}: ${err.message}';
            });
          }

          ad.dispose();
        },
        onAdOpened: (ad) {
          debugPrint('📖 Native reklam açıldı');
        },
        onAdClosed: (ad) {
          debugPrint('📕 Native reklam kapandı');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ Native reklam gösterildi (impression)');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    debugPrint('🗑️ NativeAdWidget dispose ediliyor');
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reklam yüklendiyse göster - CafeCard boyutunda
    if (_isLoaded && _nativeAd != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.orange.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    }

    // Hata varsa debug modda göster
    if (_errorMessage != null && kDebugMode) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              'Native Reklam Hatası',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 10, color: Colors.red),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Yükleniyor durumu - debug modda göster
    if (kDebugMode) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 8),
              Text(
                '⏳ Native reklam yükleniyor...',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
