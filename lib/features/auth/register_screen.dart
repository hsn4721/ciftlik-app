import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/design_system/ds.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/subscription/subscription_constants.dart';
import '../../core/subscription/subscription_service.dart';
import '../subscription/paywall_screen.dart';
import '../dashboard/dashboard_screen.dart';
import 'farm_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // Vet için zorunlu
  final _clinicCtrl = TextEditingController(); // Vet için opsiyonel
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMessage;

  /// true = yeni çiftlik kuruyor (Ana Sahip)
  /// false = davetli olarak katılıyor (vet/partner/worker — kendi çiftliğini kurmaz)
  bool _asOwner = true;

  @override
  void dispose() {
    _farmNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _clinicCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = _asOwner
        ? await AuthService.instance.registerFarm(
            farmName: _farmNameCtrl.text.trim(),
            ownerName: _ownerNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          )
        : await AuthService.instance.registerAsInvitee(
            displayName: _ownerNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            clinicName: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
            // Bu form'da non-owner toggle vet anlamına geliyor — registrationRole='vet'
            // ekrana yazılır ki sonraki login'de FarmPicker yerine paywall'a yönlensin.
            isVet: true,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Analytics — registration event
      if (_asOwner) {
        unawaited(AnalyticsService.instance.logRegisterOwner());
      } else {
        unawaited(AnalyticsService.instance.logRegisterVet());
      }
      // Vet için: trial yok, doğrudan zorunlu paywall (₺299/yıl)
      // Owner / diğer roller için: 14 gün ücretsiz Pro trial
      if (_asOwner) {
        await SubscriptionService.instance.startTrial();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (_) => false,
        );
      } else {
        // Veteriner kaydı — abonelik kontrolü
        // (Test override aktifse `state` sentetik vet state döner, paywall atlanır)
        await SubscriptionService.instance.onUserChanged();
        if (!mounted) return;
        final hasVetSub =
            SubscriptionService.instance.state.plan.hasVetAccess;
        if (hasVetSub) {
          // Abonelik mevcut (test override veya gerçek satın alma) → vet paneli
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
            (_) => false,
          );
        } else {
          // Abonelik yok → blocking paywall
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const PaywallScreen(
                vetOnly: true,
                blocking: true,
                featureName: 'Veteriner Profesyonel Aboneliği',
                reason:
                    'Veteriner panelini kullanmak için yıllık aboneliğiniz olması gerekir. '
                    'Çiftliklerden gelen davetler ve sağlık talepleri abonelik aktif edildikten sonra görünür.',
              ),
            ),
            (_) => false,
          );
        }
      }
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _asOwner ? 'Yeni Çiftlik Kur' : 'Veteriner Kaydı',
          style: DsTypography.title(color: Colors.white).copyWith(fontSize: 18),
        ),
      ),
      body: Stack(children: [
        // Gradient background
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
        Positioned(
          top: -size.width * 0.3,
          right: -size.width * 0.2,
          child: IgnorePointer(
            child: Container(
              width: size.width * 0.7, height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  DsColors.accentGreen.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
        SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Rol seçimi — Ana Sahip mi Davetli mi
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: _RoleToggle(
                      label: 'Yeni Çiftlik',
                      sub: 'Ana Sahip olacağım',
                      icon: Icons.agriculture,
                      selected: _asOwner,
                      onTap: () => setState(() => _asOwner = true),
                    )),
                    Expanded(child: _RoleToggle(
                      label: 'Veteriner Kaydı',
                      sub: 'Veteriner olarak kaydol',
                      icon: Icons.medical_services,
                      selected: !_asOwner,
                      onTap: () => setState(() => _asOwner = false),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Bilgi kartı — role göre değişir
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _asOwner
                            ? 'Ana Sahip hesabı olarak kaydoluyorsunuz. Daha sonra Ayarlar → Kullanıcı Yönetimi\'nden yardımcı, ortak, veteriner ve personel ekleyebilirsiniz.'
                            : 'Veteriner olarak kaydoluyorsunuz. Size davet gönderen çiftlik sahipleri otomatik olarak listede görünür — davetleri kabul ederek o çiftliğe üye olursunuz. Birden fazla çiftliğe aynı hesapla hizmet verebilirsiniz.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ÖNEMLİ: Bilgilerin doğru yazılması uyarısı
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ÖNEMLİ — Bilgileri Doğru Girin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _asOwner
                                ? '• Çiftlik adı: resmi kayıt adınızı yazın, sonradan zor değiştirilir.\n'
                                  '• Ad soyad: kimliğiniz ile birebir aynı olmalı.\n'
                                  '• E-posta: aktif ve size ait olmalı — davetler ve şifre sıfırlama buraya gelir.'
                                : '• Ad soyad: mesleki belgelerinizle aynı olsun.\n'
                                  '• E-posta: çiftlik sahipleri bu adrese davet gönderir — aktif ve size ait olmalı.\n'
                                  '• Şifre: en az 6 karakter, unutmayın.',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.55, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Form kartı
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_asOwner ? 'Çiftlik Bilgileri' : 'Kayıt Bilgileri',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 20),
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!,
                              style: const TextStyle(color: AppColors.errorRed, fontSize: 13))),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_asOwner) ...[
                        TextFormField(
                          controller: _farmNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Çiftlik Adı *',
                            prefixIcon: Icon(Icons.home_work_outlined, color: AppColors.primaryGreen),
                            hintText: 'Örn: Yılmaz Çiftliği',
                          ),
                          validator: (v) => _asOwner && (v == null || v.isEmpty) ? 'Çiftlik adı giriniz' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _ownerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad *',
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryGreen),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Ad soyad giriniz' : null,
                      ),
                      // Veteriner ek bilgileri — telefon zorunlu, klinik opsiyonel
                      if (!_asOwner) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefon *',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryGreen),
                            hintText: '5XX XXX XX XX',
                          ),
                          validator: (v) {
                            if (_asOwner) return null;
                            if (v == null || v.trim().isEmpty) return 'Telefon giriniz';
                            // Türk numarası: 10 hane (5XX XXX XX XX) veya
                            // 11 hane 0 başlangıçlı, ya da 12 hane +90 ile
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            String normalized = digits;
                            if (digits.length == 12 && digits.startsWith('90')) {
                              normalized = digits.substring(2);
                            } else if (digits.length == 11 && digits.startsWith('0')) {
                              normalized = digits.substring(1);
                            }
                            if (normalized.length != 10 || !normalized.startsWith('5')) {
                              return 'Geçerli bir Türkiye cep numarası giriniz (5XX XXX XX XX)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _clinicCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Klinik / Muayenehane',
                            prefixIcon: Icon(Icons.local_hospital_outlined, color: AppColors.primaryGreen),
                            hintText: 'Opsiyonel',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Giriş Bilgileri',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta *',
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryGreen),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'E-posta giriniz';
                          // RFC 5322 basit alt küme — kullanıcı (a-z0-9.+_-) @ alan.uzantı
                          final re = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                          if (!re.hasMatch(v.trim())) return 'Geçerli bir e-posta giriniz';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure1,
                        decoration: InputDecoration(
                          labelText: 'Şifre *',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryGreen),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textGrey),
                            onPressed: () => setState(() => _obscure1 = !_obscure1),
                          ),
                          helperText: 'En az 8 karakter, harf ve rakam içermeli',
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Şifre giriniz';
                          if (v.length < 8) return 'Şifre en az 8 karakter olmalı';
                          if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
                            return 'Şifre en az bir harf içermeli';
                          }
                          if (!RegExp(r'\d').hasMatch(v)) {
                            return 'Şifre en az bir rakam içermeli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        decoration: InputDecoration(
                          labelText: 'Şifre Tekrar *',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryGreen),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textGrey),
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Şifreyi tekrarlayın';
                          if (v != _passwordCtrl.text) return 'Şifreler eşleşmiyor';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 22, width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _asOwner ? 'Çiftliği Kur ve Başla' : 'Kayıt Ol',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        ),
      ]),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleToggle({
    required this.label,
    required this.sub,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primaryGreen : Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: selected ? AppColors.primaryGreen : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
          const SizedBox(height: 2),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.textGrey : Colors.white60,
                fontSize: 9,
              )),
        ]),
      ),
    );
  }
}
