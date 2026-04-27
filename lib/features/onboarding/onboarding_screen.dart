import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/design_system/ds.dart';
import '../../core/constants/app_constants.dart';
import '../auth/login_screen.dart';

/// İlk açılış onboarding turu — 4 slide.
/// SharedPrefs ile "shown" kontrolü — bir kez gösterilir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _keyShown = 'onboarding_shown';

  /// Splash sonrası çağrılır — henüz gösterilmediyse onboarding açılır.
  static Future<bool> wasShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShown) ?? false;
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShown, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _slides = const <_SlideData>[
    _SlideData(
      icon: Icons.eco_rounded,
      title: 'ÇiftlikPRO\'ya Hoş Geldiniz',
      description: 'Çiftliğinizin tüm kontrolü tek uygulamada. Hayvanlar, süt, sağlık, finans — hepsi elinizin altında.',
      color: DsColors.accentGreen,
    ),
    _SlideData(
      icon: Icons.dashboard_rounded,
      title: 'Tek Tuşla Her Modül',
      description: 'Sağım, aşı, gebelik, yem, ekipman, finans... Hepsi profesyonelce organize, kolay erişilebilir.',
      color: DsColors.infoBlue,
    ),
    _SlideData(
      icon: Icons.group_rounded,
      title: 'Ekibinle Çalış',
      description: 'Yardımcı, ortak, veteriner ve personel ekleyin. Her rolün kendi yetkileri, kendi ekranı.',
      color: DsColors.gold,
    ),
    _SlideData(
      icon: Icons.rocket_launch_rounded,
      title: 'Hemen Başlayın',
      description: 'İlk hayvanınızı ekleyin, verilerinizi takip edin. ÇiftlikPRO yanınızda.',
      color: DsColors.premium,
    ),
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markShown();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      DsFadeRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.brandGreenDark,
      body: Stack(children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF061D0A),
                Color(0xFF0A2E0F),
                Color(0xFF1B5E20),
              ],
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Atla',
                    style: DsTypography.label(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _Slide(data: _slides[i]),
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: DsMotion.fast,
                  width: active ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? DsColors.accentGreen
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Next / Start button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: () async {
                  await DsHaptic.light();
                  if (_page < _slides.length - 1) {
                    _pageCtrl.nextPage(
                      duration: DsMotion.normal,
                      curve: DsMotion.standard,
                    );
                  } else {
                    _finish();
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DsColors.accentGreen, DsColors.brandGreen],
                    ),
                    borderRadius: DsRadius.brMd,
                    boxShadow: [
                      BoxShadow(
                        color: DsColors.accentGreen.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _page < _slides.length - 1 ? 'Devam' : 'Başla',
                          style: DsTypography.subtitle(color: Colors.white)
                              .copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _page < _slides.length - 1
                              ? Icons.arrow_forward_rounded
                              : Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _SlideData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _Slide extends StatelessWidget {
  final _SlideData data;
  const _Slide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle with glow
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.color.withValues(alpha: 0.3),
                  data.color.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.4),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(data.icon, size: 80, color: data.color),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: DsTypography.titleLarge(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: DsTypography.body(color: Colors.white.withValues(alpha: 0.75))
                .copyWith(height: 1.6, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Splash sonrası gösterilecek; ilk açılışta onboarding'i gösteren wrapper.
/// Kullanım: Splash'ta `_navigate` sonrasında check et.
Future<void> maybeShowOnboarding(BuildContext context) async {
  final shown = await OnboardingScreen.wasShown();
  if (shown) return;
  if (!context.mounted) return;
  await Navigator.push(
    context,
    DsFadeRoute(builder: (_) => const OnboardingScreen()),
  );
}

// dummy usage to silence linter (AppConstants import may be removed by tooling)
// ignore: unused_element
final _hold = AppConstants.appName;
