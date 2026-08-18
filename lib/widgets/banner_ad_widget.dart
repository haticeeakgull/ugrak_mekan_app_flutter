import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 BannerAdWidget initState çağrıldı');
    debugPrint('📱 Debug mode: $kDebugMode');
    debugPrint('🆔 Kullanılan Banner ID: ${AdHelper.bannerAdUnitId}');
    _loadAd();
  }

  void _loadAd() {
    debugPrint('📲 Banner reklam yükleniyor...');
    
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner reklam başarıyla yüklendi!');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _errorMessage = null;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ Banner reklam yüklenemedi!');
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
          debugPrint('📖 Reklam açıldı');
        },
        onAdClosed: (ad) {
          debugPrint('📕 Reklam kapandı');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ Reklam gösterildi (impression)');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    debugPrint('🗑️ BannerAdWidget dispose ediliyor');
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reklam yüklendiyse göster
    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    
    // Hata varsa debug modda göster
    if (_errorMessage != null && kDebugMode) {
      return Container(
        width: double.infinity,
        height: 50,
        color: Colors.red[50],
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          '❌ $_errorMessage',
          style: const TextStyle(fontSize: 10, color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    // Yükleniyor durumu - şeffaf placeholder
    return Container(
      width: double.infinity,
      height: 50,
      color: Colors.transparent,
    );
  }
}