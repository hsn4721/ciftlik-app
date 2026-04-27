import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama erişim güvenliği:
/// - PIN (4-6 haneli, hashlenmiş) ve/veya biyometrik kilit
/// - Uygulama açılışında + arka plandan dönüşte kilit açma
/// - Finans hassas veri maskeleme toggle
///
/// Depolama stratejisi:
/// - PIN hash → FlutterSecureStorage (OS keychain / keystore)
/// - Tercihler (pin aktif, biyometri aktif, mask aktif, timeout) → SharedPreferences
class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const _keyPinHash       = 'sec_pin_hash';
  static const _keyPinSalt       = 'sec_pin_salt';
  static const _keyPinEnabled    = 'sec_pin_enabled';
  static const _keyBioEnabled    = 'sec_bio_enabled';
  static const _keyMaskFinance   = 'sec_mask_finance';
  static const _keyAutoLockMins  = 'sec_autolock_minutes';
  static const _keyLastUnlockMs  = 'sec_last_unlock_ms';

  static const int defaultAutoLockMinutes = 5;

  final _secure = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  // ─── Tercih okuma ──────────────────────────────────────────────────────

  Future<bool> isPinEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyPinEnabled) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyBioEnabled) ?? false;
  }

  Future<bool> isMaskFinanceEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyMaskFinance) ?? false;
  }

  Future<int> getAutoLockMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyAutoLockMins) ?? defaultAutoLockMinutes;
  }

  /// En az bir koruma (pin ya da biyometri) aktif mi?
  Future<bool> isLockEnabled() async {
    return (await isPinEnabled()) || (await isBiometricEnabled());
  }

  // ─── PIN işlemleri ─────────────────────────────────────────────────────

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  String _randomSalt() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return sha256.convert(utf8.encode('$now-${now * 7919}')).toString().substring(0, 16);
  }

  /// PIN oluştur veya değiştir. En az 4 hane.
  Future<String?> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 8 || !RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN 4-8 haneli sayı olmalı';
    }
    try {
      final salt = _randomSalt();
      final hash = _hash(pin, salt);
      await _secure.write(key: _keyPinHash, value: hash);
      await _secure.write(key: _keyPinSalt, value: salt);
      final p = await SharedPreferences.getInstance();
      await p.setBool(_keyPinEnabled, true);
      return null;
    } catch (e) {
      debugPrint('[SecurityService.setPin] $e');
      return 'PIN kaydedilemedi: $e';
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final hash = await _secure.read(key: _keyPinHash);
      final salt = await _secure.read(key: _keyPinSalt);
      if (hash == null || salt == null) return false;
      return _hash(pin, salt) == hash;
    } catch (e) {
      debugPrint('[SecurityService.verifyPin] $e');
      return false;
    }
  }

  /// PIN'i kaldır — biyometri da kapatılır (biyometri fallback olarak PIN ister).
  Future<void> clearPin() async {
    await _secure.delete(key: _keyPinHash);
    await _secure.delete(key: _keyPinSalt);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyPinEnabled, false);
    await p.setBool(_keyBioEnabled, false);
  }

  // ─── Biyometri ─────────────────────────────────────────────────────────

  /// Cihazda parmak izi/yüz tanıma donanımı mevcut mu?
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final available = await _auth.canCheckBiometrics;
      if (!available) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('[SecurityService.canUseBiometrics] $e');
      return false;
    }
  }

  /// Biyometri için kullanıcıya prompt göster. Dönüş: başarılı mı?
  Future<bool> authenticateBiometric({
    String reason = 'Uygulama kilidini açmak için doğrulayın',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('[SecurityService.authenticateBiometric] $e');
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyBioEnabled, enabled);
  }

  // ─── Hassas veri maskeleme ─────────────────────────────────────────────

  Future<void> setMaskFinance(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyMaskFinance, enabled);
  }

  // ─── Otomatik kilit süresi ─────────────────────────────────────────────

  Future<void> setAutoLockMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyAutoLockMins, minutes.clamp(0, 60));
  }

  // ─── Kilit açma zamanı takibi ──────────────────────────────────────────

  Future<void> markUnlocked() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyLastUnlockMs, DateTime.now().millisecondsSinceEpoch);
  }

  /// Son kilit açıldığından bu yana [autoLockMinutes] geçti mi?
  /// 0 ise her açılışta istenir, sadece hiç açılmamışsa zorunlu.
  Future<bool> shouldRequireUnlock() async {
    if (!await isLockEnabled()) return false;
    final autoLock = await getAutoLockMinutes();
    if (autoLock == 0) return true;
    final p = await SharedPreferences.getInstance();
    final lastMs = p.getInt(_keyLastUnlockMs);
    if (lastMs == null) return true;
    final elapsedMin = (DateTime.now().millisecondsSinceEpoch - lastMs) ~/ 60000;
    return elapsedMin >= autoLock;
  }
}
