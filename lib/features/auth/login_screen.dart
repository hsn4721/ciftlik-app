import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/design_system/ds.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/subscription/subscription_service.dart';
import '../../core/subscription/subscription_constants.dart';
import '../subscription/paywall_screen.dart';
import '../dashboard/dashboard_screen.dart';
import 'farm_picker_screen.dart';
import 'register_screen.dart';

/// Premium login ekranı — gradient bg, glass form, staggered animations.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  late final AnimationController _entryCtrl;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoFade = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOut));
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOutCubic)),
    );
    _formFade = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.25, 0.8, curve: Curves.easeOut));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic)),
    );
    _footerFade = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut));
    _entryCtrl.forward();

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final email = await AuthService.instance.getSavedEmail();
    if (email == null || !mounted) return;
    final password = await AuthService.instance.getSavedPassword();
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
      _rememberMe = true;
      if (password != null) _passwordController.text = password;
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await AuthService.instance.signIn(
      _emailController.text,
      _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Yeni kullanıcı için subscription state yükle
      await SubscriptionService.instance.onUserChanged();
      if (!mounted) return;
      if (result.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çevrimdışı modda giriş yapıldı'),
            backgroundColor: DsColors.gold,
          ),
        );
      }
      _routeAfterLogin();
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  void _routeAfterLogin() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final isVetUser = user.isVet ||
        user.memberships.values.any((m) => m.isActive && m.role == AppConstants.roleVet);

    if (isVetUser) {
      // Veteriner: abonelik zorunlu — yoksa paywall
      final vetActive = SubscriptionService.instance.state.plan.hasVetAccess;
      if (!vetActive) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(
              vetOnly: true,
              blocking: true,
              featureName: 'Veteriner Profesyonel Aboneliği',
              reason:
                  'Çiftliklerden gelen davetler ve sağlık talepleri görüntülemek için '
                  'yıllık aboneliğiniz olmalı.',
            ),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
      );
      return;
    }

    final hasActive = user.activeFarmId != null &&
        user.memberships[user.activeFarmId]?.isActive == true;
    final Widget next = hasActive ? const DashboardScreen() : const FarmPickerScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Şifre sıfırlama için e-posta giriniz');
      return;
    }
    setState(() => _isLoading = true);
    final error = await AuthService.instance.sendPasswordReset(_emailController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.mark_email_read_outlined, color: DsColors.brandGreen),
            SizedBox(width: 10),
            Text('Mail Gönderildi'),
          ]),
          content: const Text(
            'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.\n\n'
            '📌 Mail gelmediyse "Spam" veya "Gereksiz" klasörünü kontrol edin.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
          ],
        ),
      );
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        // ─── Gradient Background ────────────────────
        Container(
          width: double.infinity, height: double.infinity,
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

        // ─── Ambient Glow ───────────────────────────
        Positioned(
          top: -size.width * 0.35,
          right: -size.width * 0.2,
          child: _glow(size.width * 0.8, DsColors.accentGreen.withValues(alpha: 0.12)),
        ),
        Positioned(
          bottom: -size.width * 0.3,
          left: -size.width * 0.15,
          child: _glow(size.width * 0.7, DsColors.gold.withValues(alpha: 0.05)),
        ),

        // ─── Content ────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Logo (gerçek app_icon, splash ile aynı görsel)
                FadeTransition(
                  opacity: _logoFade,
                  child: SlideTransition(
                    position: _logoSlide,
                    child: const _LogoMark(),
                  ),
                ),

                const SizedBox(height: 24),

                // Büyük slogan — "Çiftliğinizin Tüm Kontrolü - TEK EKRANDA"
                FadeTransition(
                  opacity: _logoFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          'Çiftliğinizin Tüm Kontrolü',
                          textAlign: TextAlign.center,
                          style: DsTypography.headline(
                            color: Colors.white.withValues(alpha: 0.85),
                          ).copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFFFD60A),
                              Colors.white,
                              Color(0xFFB8F2C4),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'TEK EKRANDA',
                            textAlign: TextAlign.center,
                            style: DsTypography.display(color: Colors.white).copyWith(
                              fontSize: 32,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Glass form
                FadeTransition(
                  opacity: _formFade,
                  child: SlideTransition(
                    position: _formSlide,
                    child: _glassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Giriş Yap',
                                style: DsTypography.title(color: DsColors.neutral900)),
                            const SizedBox(height: 6),
                            Text('Hesabınıza giriş yapın',
                                style: DsTypography.body(color: DsColors.neutral600)),
                            const SizedBox(height: 24),

                            if (_errorMessage != null) ...[
                              _ErrorBanner(message: _errorMessage!),
                              const SizedBox(height: 16),
                            ],

                            // E-posta
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: DsTypography.body(color: DsColors.neutral900),
                              decoration: InputDecoration(
                                labelText: 'E-posta',
                                labelStyle: DsTypography.body(color: DsColors.neutral600),
                                prefixIcon: const Icon(Icons.email_outlined, color: DsColors.brandGreen, size: 20),
                                filled: true,
                                fillColor: DsColors.neutral50,
                                border: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: BorderSide(color: DsColors.neutral200, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: BorderSide(color: DsColors.neutral200, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: const BorderSide(color: DsColors.brandGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'E-posta giriniz';
                                if (!v.contains('@')) return 'Geçersiz e-posta';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Şifre
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: DsTypography.body(color: DsColors.neutral900),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                labelStyle: DsTypography.body(color: DsColors.neutral600),
                                prefixIcon: const Icon(Icons.lock_outline, color: DsColors.brandGreen, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: DsColors.neutral600,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: DsColors.neutral50,
                                border: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: BorderSide(color: DsColors.neutral200, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: BorderSide(color: DsColors.neutral200, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: DsRadius.brMd,
                                  borderSide: const BorderSide(color: DsColors.brandGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Şifre giriniz' : null,
                            ),
                            const SizedBox(height: 14),

                            // Beni hatırla + şifremi unuttum
                            Row(children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: _rememberMe ? DsColors.brandGreen : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _rememberMe ? DsColors.brandGreen : DsColors.neutral300,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: _rememberMe
                                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Beni Hatırla',
                                      style: DsTypography.bodySmall(color: DsColors.neutral700)),
                                ]),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _isLoading ? null : _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Şifremi Unuttum',
                                    style: DsTypography.label(color: DsColors.brandGreen)),
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // Giriş butonu
                            _GradientButton(
                              label: 'Giriş Yap',
                              loading: _isLoading,
                              onPressed: _isLoading ? null : _login,
                              icon: Icons.arrow_forward_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Register shortcut
                FadeTransition(
                  opacity: _footerFade,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: DsRadius.brMd,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      icon: const Icon(Icons.add_home_work_outlined, color: Colors.white, size: 18),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Çiftlik Kur veya Veteriner Kaydı Ol',
                            style: DsTypography.subtitle(color: Colors.white)),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Alt güvence
                FadeTransition(
                  opacity: _footerFade,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FeatureChip(icon: Icons.wifi_off_rounded, label: 'Çevrimdışı'),
                      const SizedBox(width: 10),
                      _FeatureChip(icon: Icons.security_rounded, label: 'Güvenli'),
                      const SizedBox(width: 10),
                      _FeatureChip(icon: Icons.cloud_sync_rounded, label: 'Senkron'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glow(double d, Color c) {
    return IgnorePointer(
      child: Container(
        width: d, height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, Colors.transparent]),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: DsRadius.brXl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: DsRadius.brXl,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Logo Mark — Splash ile tutarlı ───────────────────
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: DsColors.accentGreen.withValues(alpha: 0.45),
            blurRadius: 50,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DsColors.errorRed.withValues(alpha: 0.08),
        borderRadius: DsRadius.brSm,
        border: Border.all(color: DsColors.errorRed.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: DsColors.errorRed, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: DsTypography.bodySmall(color: DsColors.errorRed)),
        ),
      ]),
    );
  }
}

// ─── Gradient Button ──────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const _GradientButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: DsRadius.brMd,
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [DsColors.accentGreen, DsColors.brandGreen],
                )
              : null,
          color: enabled ? null : DsColors.neutral200,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: DsColors.brandGreen.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: DsTypography.subtitle(color: Colors.white).copyWith(fontSize: 16)),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Feature chip ─────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: DsRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: DsTypography.caption(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
