import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _iconAnimationController;
  late AnimationController _textAnimationController;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.explore,
      title: 'Keşfet',
      description: 'Haritada kafeleri keşfet, sana özel öneriler al. AI destekli arama ile tam istediğin mekanı bul.',
      color: const Color(0xFF346739),
    ),
    OnboardingPage(
      icon: Icons.search,
      title: 'Akıllı Arama',
      description: 'Doğal dille ara! "Sakin ve huzurlu bir kafe" gibi aramalar yap, yapay zeka sana en uygun mekanları bulsun.',
      color: const Color(0xFFFF6B35),
    ),
    OnboardingPage(
      icon: Icons.collections_bookmark,
      title: 'Koleksiyonlar',
      description: 'Favori kafelerini koleksiyonlarda topla, arkadaşlarınla paylaş. Başkalarının koleksiyonlarını keşfet.',
      color: const Color(0xFF4ECDC4),
    ),
    OnboardingPage(
      icon: Icons.photo_camera,
      title: 'Paylaş & Keşfet',
      description: 'Gittiğin kafeleri fotoğrafla, deneyimlerini paylaş. Diğer kullanıcıların önerilerini incele.',
      color: const Color(0xFFF7B731),
    ),
    OnboardingPage(
      icon: Icons.leaderboard,
      title: 'Liderlik Tablosu',
      description: 'Puan kazan, rozetler topla! En aktif kullanıcılar arasına katıl, özel rozetler kazan.',
      color: const Color(0xFF5F27CD),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconAnimationController.forward();
    _textAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // Sayfa değiştiğinde animasyonları yeniden başlat
    _iconAnimationController.reset();
    _textAnimationController.reset();
    _iconAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _textAnimationController.forward();
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (widget.onComplete != null) {
      // Callback varsa çağır (AuthWrapper için)
      widget.onComplete!();
    } else if (mounted) {
      // Callback yoksa pop yap (profil ekranından açıldıysa)
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
          child: Column(
            children: [
              // Üst bar - Atla butonu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo veya uygulama adı
                    Text(
                      'Uğrak',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _pages[_currentPage].color,
                      ),
                    ),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Atla',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sayfa içeriği
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
              // Nokta göstergeleri
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? _pages[_currentPage].color
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
              // Alt butonlar
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Geri butonu
                    if (_currentPage > 0)
                      TextButton.icon(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Geri'),
                        style: TextButton.styleFrom(
                          foregroundColor: _pages[_currentPage].color,
                        ),
                      )
                    else
                      const SizedBox(width: 80),
                    // İleri/Başla butonu
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Başla'
                                : 'İleri',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İkon - Animasyonlu
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _iconAnimationController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                page.icon,
                size: 80,
                color: page.color,
              ),
            ),
          ),
          const SizedBox(height: 50),
          // Başlık - Animasyonlu
          FadeTransition(
            opacity: _textAnimationController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _textAnimationController,
                curve: Curves.easeOut,
              )),
              child: Text(
                page.title,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: page.color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Açıklama - Animasyonlu
          FadeTransition(
            opacity: _textAnimationController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _textAnimationController,
                curve: Curves.easeOut,
              )),
              child: Text(
                page.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
