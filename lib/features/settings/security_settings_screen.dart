import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/security_service.dart';

/// Güvenlik ayarları — PIN, biyometri, otomatik kilit, finans maskeleme.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _security = SecurityService.instance;

  bool _pinEnabled = false;
  bool _bioEnabled = false;
  bool _canUseBio = false;
  bool _maskFinance = false;
  int _autoLockMin = SecurityService.defaultAutoLockMinutes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pin = await _security.isPinEnabled();
    final bio = await _security.isBiometricEnabled();
    final canBio = await _security.canUseBiometrics();
    final mask = await _security.isMaskFinanceEnabled();
    final autoLock = await _security.getAutoLockMinutes();
    if (!mounted) return;
    setState(() {
      _pinEnabled = pin;
      _bioEnabled = bio;
      _canUseBio = canBio;
      _maskFinance = mask;
      _autoLockMin = autoLock;
      _loading = false;
    });
  }

  // ─── PIN ────────────────────────────────────────────────────────────────

  Future<void> _togglePin(bool enabled) async {
    if (enabled) {
      await _setupNewPin();
    } else {
      await _disablePin();
    }
  }

  Future<void> _setupNewPin() async {
    final pin = await _askNewPin();
    if (pin == null) return;
    final err = await _security.setPin(pin);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    await _security.markUnlocked();
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN oluşturuldu — uygulama kilidi aktif'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _disablePin() async {
    final currentPin = await _askPin(title: 'Mevcut PIN', subtitle: 'PIN kilidini kaldırmak için doğrulayın');
    if (currentPin == null) return;
    final ok = await _security.verifyPin(currentPin);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN yanlış'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    await _security.clearPin();
    _load();
  }

  Future<void> _changePin() async {
    final oldPin = await _askPin(title: 'Mevcut PIN');
    if (oldPin == null) return;
    final ok = await _security.verifyPin(oldPin);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mevcut PIN yanlış'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    await _setupNewPin();
  }

  /// Çift PIN girişi (yeni + onay).
  Future<String?> _askNewPin() async {
    final first = TextEditingController();
    final second = TextEditingController();
    String? err;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(builder: (stCtx, setSt) {
          return AlertDialog(
            title: const Text('Yeni PIN'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('4-8 haneli sayısal PIN', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 12),
                _PinField(controller: first, label: 'PIN'),
                const SizedBox(height: 12),
                _PinField(controller: second, label: 'PIN (Tekrar)'),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  Text(err!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () {
                  final a = first.text.trim();
                  final b = second.text.trim();
                  if (a.length < 4 || a.length > 8 || !RegExp(r'^\d+$').hasMatch(a)) {
                    setSt(() => err = '4-8 haneli sayısal PIN girin');
                    return;
                  }
                  if (a != b) {
                    setSt(() => err = 'PIN\'ler eşleşmiyor');
                    return;
                  }
                  Navigator.pop(dCtx, a);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<String?> _askPin({required String title, String? subtitle}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (subtitle != null) ...[
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 10),
          ],
          _PinField(controller: ctrl, label: 'PIN'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Biyometri ──────────────────────────────────────────────────────────

  Future<void> _toggleBio(bool enabled) async {
    if (enabled) {
      if (!_pinEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce PIN oluşturun (biyometri yedek olarak PIN ister)')),
        );
        return;
      }
      final ok = await _security.authenticateBiometric(
        reason: 'Biyometrik kilidi etkinleştirmek için doğrulayın',
      );
      if (!ok) return;
      await _security.setBiometricEnabled(true);
    } else {
      await _security.setBiometricEnabled(false);
    }
    _load();
  }

  // ─── Diğer ──────────────────────────────────────────────────────────────

  Future<void> _toggleMaskFinance(bool enabled) async {
    await _security.setMaskFinance(enabled);
    setState(() => _maskFinance = enabled);
  }

  Future<void> _pickAutoLock() async {
    final options = [0, 1, 5, 15, 30, 60];
    final sel = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Otomatik Kilitlenme'),
        children: options.map((v) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, v),
          child: Row(children: [
            Icon(
              v == _autoLockMin ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppColors.primaryGreen, size: 20,
            ),
            const SizedBox(width: 10),
            Text(v == 0 ? 'Her açılışta' : '$v dakika sonra'),
          ]),
        )).toList(),
      ),
    );
    if (sel != null) {
      await _security.setAutoLockMinutes(sel);
      setState(() => _autoLockMin = sel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(title: 'Uygulama Kilidi', children: [
                  SwitchListTile(
                    title: const Text('PIN Kilidi'),
                    subtitle: const Text('Uygulama açılışında 4-8 haneli PIN iste'),
                    value: _pinEnabled,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: _togglePin,
                  ),
                  if (_pinEnabled)
                    ListTile(
                      leading: const Icon(Icons.pin, color: AppColors.primaryGreen),
                      title: const Text('PIN Değiştir'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                    ),
                  SwitchListTile(
                    title: const Text('Parmak İzi / Yüz Tanıma'),
                    subtitle: Text(
                      !_canUseBio
                          ? 'Cihazınızda biyometrik doğrulama yok'
                          : !_pinEnabled
                              ? 'Önce PIN oluşturun'
                              : 'Destekli — parmak izi veya yüz tanıma',
                    ),
                    value: _bioEnabled && _canUseBio,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (!_canUseBio || !_pinEnabled) ? null : _toggleBio,
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: AppColors.primaryGreen),
                    title: const Text('Otomatik Kilitlenme'),
                    subtitle: Text(_autoLockMin == 0
                        ? 'Her açılışta'
                        : '$_autoLockMin dakika arka plandan sonra'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickAutoLock,
                    enabled: _pinEnabled || _bioEnabled,
                  ),
                ]),
                const SizedBox(height: 12),
                _SectionCard(title: 'Hassas Veri', children: [
                  SwitchListTile(
                    title: const Text('Finans Tutarlarını Gizle'),
                    subtitle: const Text(
                      'Finans ekranlarında tutarlar ••••• olarak gösterilir. '
                      'Detay için tıklayın.',
                    ),
                    value: _maskFinance,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: _toggleMaskFinance,
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, color: AppColors.infoBlue, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PIN cihazınızın Keystore\'unda hashlenerek saklanır. '
                        'Unutursanız uygulamayı silip yeniden kurmanız gerekir — '
                        'Firebase verileriniz korunur.',
                        style: TextStyle(fontSize: 11, color: AppColors.infoBlue, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _PinField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 8,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 20, letterSpacing: 6),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
