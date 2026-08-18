import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ugrak_mekan_app/widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  final SupabaseClient supabase = Supabase.instance.client;

  /// Google ile Giriş Fonksiyonu
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // ÖNEMLI: Bu Google Cloud Console'dan aldığınız WEB Client ID olmalı
      // (Android Client ID değil!)
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];

      if (webClientId == null || webClientId.isEmpty) {
        throw 'GOOGLE_WEB_CLIENT_ID .env dosyasında tanımlanmamış!';
      }

      debugPrint('🔐 Google Sign-In başlatılıyor...');
      debugPrint('📱 Web Client ID: ${webClientId.substring(0, 20)}...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      debugPrint('👤 Google hesap seçimi açılıyor...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ Kullanıcı Google girişini iptal etti');
        setState(() => _isLoading = false);
        return; // Kullanıcı seçim yapmadan pencereyi kapattı
      }

      debugPrint('✅ Google hesabı seçildi: ${googleUser.email}');
      debugPrint('🔑 Google authentication bilgileri alınıyor...');
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google ID Token bulunamadı.';
      }

      debugPrint('📤 Supabase\'e gönderiliyor...');
      
      // Supabase'e Google kimlik bilgilerini gönderiyoruz
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('🎉 Google ile giriş başarılı!');
      
      // Giriş başarılı!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google ile giriş başarılı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Platform Exception: ${e.code} - ${e.message}');
      
      String userMessage = 'Google ile giriş başarısız oldu.';
      
      // Hata koduna göre kullanıcı dostu mesajlar
      if (e.code == 'sign_in_failed') {
        if (e.message?.contains('10') == true) {
          userMessage = 'Google OAuth yapılandırması eksik!\n\n'
              'Lütfen geliştiriciyle iletişime geçin.\n'
              '(Hata: SHA-1 fingerprint eklenmelı)';
        } else if (e.message?.contains('12501') == true) {
          userMessage = 'Giriş iptal edildi';
          setState(() => _isLoading = false);
          return; // Snackbar gösterme
        } else {
          userMessage = 'Google ile giriş başarısız: ${e.message}';
        }
      } else if (e.code == 'network_error') {
        userMessage = 'İnternet bağlantısını kontrol edin';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Bilinmeyen hata: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// E-posta/Şifre ile Giriş veya Kayıt Fonksiyonu
  Future<void> _authenticate() async {
    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      _showError('Şifreler birbiriyle eşleşmiyor!');
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Lütfen tüm alanları doldurun!');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kayıt başarılı!')));
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Renk paleti
    const Color deepGreen = Color(0xFF346739);
    const Color midGreen = Color(0xFF79AE6F);
    const Color vanilla = Color(0xFFFAF8F3);
    
    return AppScaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/ugrak_logo.jpg',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 30),

              // E-posta alanı
              _buildTextField(
                _emailController,
                'E-posta',
                Icons.email_outlined,
              ),
              const SizedBox(height: 16),

              // Şifre alanı
              _buildTextField(
                _passwordController,
                'Şifre',
                Icons.lock_outline,
                obscure: true,
              ),

              if (!_isLogin) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  _confirmPasswordController,
                  'Şifreyi Onayla',
                  Icons.lock_reset_rounded,
                  obscure: true,
                ),
              ],

              const SizedBox(height: 24),

              // Giriş/Kaydol Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? "Giriş Yap" : "Hesap Oluştur",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // --- VEYA Bölümü ---
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "veya",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Google ile Giriş Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: midGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logoyu sarmalayıp boyutunu kısıtlıyoruz
                      Image.network(
                        'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.account_circle,
                              size: 20,
                            ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Google ile Devam Et",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),

              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? "Hesabın yok mu? Kaydol"
                      : "Zaten üyen misin? Giriş yap",
                  style: const TextStyle(color: deepGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
