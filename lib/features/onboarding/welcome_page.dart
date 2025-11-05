// lib/features/onboarding/welcome_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/storage/secure_storage.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onComplete});
  
  final VoidCallback onComplete;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WelcomeSlide> _slides = [
    WelcomeSlide(
      title: 'Bine ai venit!',
      description: 'Bun venit în Logopedy, aplicația care te ajută să dezvolți abilitățile de comunicare și vorbire într-un mod interactiv și distractiv.',
      icon: Icons.waving_hand,
      color: const Color(0xFF2D72D2),
    ),
    WelcomeSlide(
      title: 'Scopul aplicației',
      description: 'Logopedy este creată pentru a te ajuta să progresezi prin exerciții practice și lecții personalizate. Fiecare utilizator poate lucra în ritmul său propriu.',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFEA2233),
    ),
    WelcomeSlide(
      title: 'Profile multiple',
      description: 'Poți crea mai multe profile în aplicație - unul pentru fiecare copil sau utilizator. Fiecare profil păstrează progresul său individual.',
      icon: Icons.group_rounded,
      color: const Color(0xFF2D72D2),
    ),
    WelcomeSlide(
      title: 'Creează primul profil',
      description: 'Pentru a începe, ai nevoie de cel puțin un profil activ. Creează primul profil pentru a accesa modulele și lecțiile.',
      icon: Icons.person_add_rounded,
      color: const Color(0xFFEA2233),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await GetIt.I<SecureStore>().writeKey('onboarding_completed', 'true');
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            if (_currentPage < _slides.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Sari peste',
                      style: TextStyle(
                        color: Color(0xFF17406B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _WelcomeSlideWidget(slide: _slides[index]);
                },
              ),
            ),
            
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xFFEA2233)
                          : const Color(0xFFEA2233).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            
            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA2233), Color(0xFFD21828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA2233).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      _currentPage < _slides.length - 1 ? 'Următorul' : 'Începe',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSlideWidget extends StatelessWidget {
  final WelcomeSlide slide;

  const _WelcomeSlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide.icon,
              size: 64,
              color: slide.color,
            ),
          ),
          const SizedBox(height: 48),
          
          // Title
          Text(
            slide.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17406B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Description
          Text(
            slide.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[700],
              height: 1.6,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class WelcomeSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  WelcomeSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

