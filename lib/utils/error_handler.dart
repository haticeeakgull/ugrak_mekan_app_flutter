import 'package:flutter/foundation.dart';

/// Kullanıcı dostu hata mesajları için yardımcı sınıf
class ErrorHandler {
  /// Teknik hataları kullanıcı dostu mesajlara çevirir
  static String getUserFriendlyMessage(dynamic error) {
    final String errorString = error.toString().toLowerCase();
    
    // Debug modda teknik detayları logla
    if (kDebugMode) {
      debugPrint('🔴 Teknik Hata Detayı: $error');
    }
    
    // Ağ ve bağlantı hataları
    if (errorString.contains('socket') || 
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
    
    // Timeout hataları
    if (errorString.contains('timeout') || 
        errorString.contains('57014') ||
        errorString.contains('timed out')) {
      return 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }
    
    // Kimlik doğrulama hataları
    if (errorString.contains('auth') || 
        errorString.contains('unauthorized') ||
        errorString.contains('token')) {
      return 'Oturumunuz sonlanmış. Lütfen tekrar giriş yapın.';
    }
    
    // Veri bulunamadı hataları
    if (errorString.contains('not found') || 
        errorString.contains('404')) {
      return 'Aradığınız içerik bulunamadı.';
    }
    
    // Sunucu hataları
    if (errorString.contains('500') || 
        errorString.contains('server error') ||
        errorString.contains('internal')) {
      return 'Sunucuda bir sorun oluştu. Lütfen daha sonra tekrar deneyin.';
    }
    
    // İzin hataları
    if (errorString.contains('permission') || 
        errorString.contains('forbidden') ||
        errorString.contains('403')) {
      return 'Bu işlem için yetkiniz bulunmuyor.';
    }
    
    // Veri format hataları
    if (errorString.contains('format') || 
        errorString.contains('parse') ||
        errorString.contains('invalid')) {
      return 'Veri formatı hatalı. Lütfen bilgilerinizi kontrol edin.';
    }
    
    // Konum hataları
    if (errorString.contains('location')) {
      return 'Konum bilgisi alınamadı. Konum servislerini kontrol edin.';
    }
    
    // Embedding/AI hataları
    if (errorString.contains('embedding') || 
        errorString.contains('api') ||
        errorString.contains('hf')) {
      return 'Yapay zeka servisi şu anda kullanılamıyor. Normal arama ile devam edebilirsiniz.';
    }
    
    // Database hataları
    if (errorString.contains('sql') || 
        errorString.contains('database') ||
        errorString.contains('does not exist')) {
      return 'Veritabanı işlemi başarısız oldu. Lütfen tekrar deneyin.';
    }
    
    // Varsayılan genel hata mesajı
    return 'Bir sorun oluştu. Lütfen tekrar deneyin.';
  }
  
  /// Hata mesajını snackbar için formatlar
  static Map<String, dynamic> getErrorSnackbarConfig(dynamic error) {
    final message = getUserFriendlyMessage(error);
    final errorString = error.toString().toLowerCase();
    
    // Timeout hatalarında "Tekrar Dene" butonu göster
    final bool shouldShowRetry = errorString.contains('timeout') || 
                                 errorString.contains('57014') ||
                                 errorString.contains('timed out') ||
                                 errorString.contains('network');
    
    return {
      'message': message,
      'showRetry': shouldShowRetry,
    };
  }
  
  /// Kolay kullanım için statik metod
  static void logError(String context, dynamic error) {
    if (kDebugMode) {
      debugPrint('❌ [$context] Hata: $error');
      if (error is Error) {
        debugPrint('Stack Trace: ${error.stackTrace}');
      }
    }
  }
}
