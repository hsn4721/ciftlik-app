import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../firebase_options.dart';
import '../../core/design_system/ds.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/payment_reminder_sync.dart';
import '../../core/services/security_service.dart';
import '../../core/subscription/subscription_service.dart';
import '../../core/constants/app_constants.dart';
import '../auth/login_screen.dart';
import '../auth/lock_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Sinematik premium splash — gradient + particles + glow + staggered title.
/// Apple Design Awards seviyesinde ilk etki.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _particlesCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoGlow;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _loaderFade;

  // Rastgele parçacıklar (özgün her build)
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _particlesCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack);
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOut));
    _logoGlow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _titleFade = CurvedAnimation(parent: _textCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic)));
    _loaderFade = CurvedAnimation(parent: _textCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut));

    final rnd = math.Random(42);
    _particles = List.generate(14, (i) => _Particle.random(rnd));

    // Status bar'ı saydam yap (gradient bg için)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A2E0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    FlutterNativeSplash.remove();
    _startSequence();
  }

  Future<void> _startSequence() async {
    final initFuture = _initApp();
    await Future.delayed(const Duration(milliseconds: 150));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _textCtrl.forward();
    await initFuture;
    await Future.delayed(const Duration(milliseconds: 400));
    _navigate();
  }

  Future<void> _initApp() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // Crashlytics — Firebase init sonrası açılmalı; debug'da kapalı.
      await AppLogger.init(collectInDebug: false);
      await AnalyticsService.instance.init();
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      await NotificationService.instance.init();
      await SubscriptionService.instance.init();
      await PaymentReminderSync.rescheduleAll();
    } catch (e, st) {
      AppLogger.error('splash.init', e, st);
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    // İlk açılış — onboarding göster
    final onboardingShown = await OnboardingScreen.wasShown();
    if (!onboardingShown && mounted) {
      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, anim, __) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
      return;
    }
    // Güvenlik kilidi aktifse kilit ekranı aç
    final shouldLock = await SecurityService.instance.shouldRequireUnlock();
    if (shouldLock && mounted) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const LockScreen(allowExit: true),
        ),
      );
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, anim, __) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _glowCtrl.dispose();
    _particlesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Katman 1: Ana gradient ────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF061D0A),
                  Color(0xFF0A2E0F),
                  Color(0xFF1B5E20),
                  Color(0xFF267F2C),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // ─── Katman 2: Radial glow spots ────────────
          Positioned(
            top: -size.width * 0.35,
            right: -size.width * 0.25,
            child: _glowBlob(size.width * 0.85, DsColors.accentGreen.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: _glowBlob(size.width * 0.75, DsColors.gold.withValues(alpha: 0.05)),
          ),
          Positioned(
            top: size.height * 0.4,
            left: size.width * 0.1,
            child: _glowBlob(size.width * 0.4, Colors.white.withValues(alpha: 0.03)),
          ),

          // ─── Katman 3: Parçacıklar (animated) ───────
          AnimatedBuilder(
            animation: _particlesCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particlesCtrl.value,
                size: size,
              ),
              size: Size.infinite,
            ),
          ),

          // ─── Katman 4: Ana içerik ───────────────────
          SafeArea(
            child: Stack(
              children: [
                // Logo + başlık: ekranın TAM ORTASINDA
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_logoCtrl, _glowCtrl]),
                        builder: (_, __) {
                          final glow = 0.3 + (_logoGlow.value * 0.5);
                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.5, end: 1.0).animate(_logoScale),
                              child: Container(
                                width: 160, height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: DsColors.accentGreen.withValues(alpha: glow),
                                      blurRadius: 80,
                                      spreadRadius: 16,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.asset(
                                    'assets/images/app_icon.png',
                                    width: 160,
                                    height: 160,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFB8F2C4)],
                            ).createShader(bounds),
                            child: Text(
                              AppConstants.appName,
                              textAlign: TextAlign.center,
                              style: DsTypography.display(color: Colors.white).copyWith(
                                fontSize: 44,
                                letterSpacing: -1.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Alt kısım: shimmer bar + imza (ekran altına sabit)
                Positioned(
                  left: 0, right: 0, bottom: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _loaderFade,
                        child: Container(
                          width: 120, height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const _ShimmerBar(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _loaderFade,
                        child: Text(
                          'Yükleniyor...',
                          style: DsTypography.caption(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _loaderFade,
                        child: Text(
                          'ÇiftlikPRO · 2026',
                          style: DsTypography.caption(color: Colors.white.withValues(alpha: 0.35))
                              .copyWith(letterSpacing: 2, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(double diameter, Color color) {
    return IgnorePointer(
      child: Container(
        width: diameter, height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─── Parçacıklar ────────────────────────────────────────
class _Particle {
  final double xStart;
  final double yStart;
  final double speedY;
  final double size;
  final double opacity;
  final double drift;
  final double phase;

  _Particle({
    required this.xStart,
    required this.yStart,
    required this.speedY,
    required this.size,
    required this.opacity,
    required this.drift,
    required this.phase,
  });

  factory _Particle.random(math.Random r) {
    return _Particle(
      xStart: r.nextDouble(),
      yStart: r.nextDouble(),
      speedY: 0.15 + r.nextDouble() * 0.3,
      size: 1.5 + r.nextDouble() * 2.5,
      opacity: 0.15 + r.nextDouble() * 0.3,
      drift: (r.nextDouble() - 0.5) * 0.1,
      phase: r.nextDouble() * math.pi * 2,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Size size;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final p in particles) {
      final yProgress = (p.yStart + progress * p.speedY) % 1.0;
      final y = canvasSize.height * (1.0 - yProgress); // yukarı hareket
      final x = canvasSize.width *
          (p.xStart + math.sin(progress * math.pi * 2 + p.phase) * p.drift);
      final alpha = p.opacity * (1 - (yProgress - 0.5).abs() * 2).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}

// ─── Shimmer Bar ────────────────────────────────────────
class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar();

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(children: [
            Positioned(
              left: _ctrl.value * 120 - 40,
              child: Container(
                width: 40, height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      DsColors.accentGreen,
                      Colors.white,
                      DsColors.accentGreen,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DsColors.accentGreen.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
