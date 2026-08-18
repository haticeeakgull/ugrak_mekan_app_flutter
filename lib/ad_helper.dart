import 'package:flutter/foundation.dart';

class AdHelper {
  // Test ID'leri
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testNativeId = 'ca-app-pub-3940256099942544/2247696110';

  // Gerçek ID'lerin
  static const String _realBannerId = 'ca-app-pub-3462924768349720/7169936169';
  static const String _realNativeId = 'ca-app-pub-3462924768349720/9088738673';

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return _testBannerId; // Debug modda test ID
    }
    return _realBannerId; // Canlıda gerçek ID
  }

  static String get nativeAdUnitId {
    if (kDebugMode) {
      return _testNativeId; // Debug modda test ID
    }
    return _realNativeId; // Canlıda gerçek ID
  }
}