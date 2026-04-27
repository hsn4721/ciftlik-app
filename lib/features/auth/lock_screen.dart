import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/security_service.dart';
import '../../core/services/auth_service.dart';

/// Uygulama kilidi ekranı — PIN ve/veya biyometri doğrulaması.
/// Başarılı olunca `Navigator.pop(context, true)` döner.
class LockScreen extends StatefulWidget {
  /// Kilit ekranından çıkışa izin verme (ör. sign-out akışı). False ise geri
  /// tuşu kapatılır; yalnızca doğrulama başarılıysa ekran kapanır.
  final bool allowExit;
  const LockScreen({super.key, this.allowExit = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _security = SecurityService.instance;
  final _pinCtrl = TextEditingController();
  bool _isPinEnabled = false;
  bool _isBioEnabled = false;
  bool _canUseBio = false;
  bool _busy = false;
  String? _error;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _initChecks();
  }

  Future<void> _initChecks() async {
    final pin = await _security.isPinEnabled();
    final bio = await _security.isBiometricEnabled();
    final canBio = await _security.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _isPinEnabled = pin;
      _isBioEnabled = bio;
      _canUseBio = canBio;
    });
    // Biyometri aktifse otomatik olarak prompt aç
    if (bio && canBio) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _busy = true);
    final ok = await _security.authenticateBiometric();
    if (!mounted) return;
    if (ok) {
      await _security.markUnlocked();
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _tryPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    final ok = await _security.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      await _security.markUnlocked();
      if (mounted) Navigator.pop(context, true);
    } else {
      _attempts++;
      setState(() {
        _busy = false;
        _pinCtrl.clear();
        _error = _attempts >= 3
            ? 'Yanlış PIN — $_attempts deneme'
            : 'Yanlış PIN';
      });
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.signOut();
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.allowExit,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A2E0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'ÇiftlikPRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uygulama kilidini açın',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 40),
                if (_isPinEnabled) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      TextField(
                        controller: _pinCtrl,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 8,
                        style: const TextStyle(fontSize: 28, letterSpacing: 8),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          counterText: '',
                          errorText: _error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _tryPin(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _tryPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Kilidi Aç',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (_isBioEnabled && _canUseBio) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _busy ? null : _tryBiometric,
                    icon: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                    label: const Text(
                      'Parmak İzi / Yüz Tanıma',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _busy ? null : _signOut,
                  child: const Text(
                    'Çıkış Yap',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
