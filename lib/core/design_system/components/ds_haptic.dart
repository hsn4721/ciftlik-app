import 'package:flutter/services.dart';

/// Haptic feedback wrapper — platform-adaptive, kolay kullanım.
///
/// Kritik eylemlerde kullanılır: silme, onay, başarı, hata.
class DsHaptic {
  DsHaptic._();

  /// Hafif tap (button press, chip seçimi) — en yaygın.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Orta şiddet (switch toggle, segment switch).
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Ağır (silme onayı, kritik eylem).
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Seçim değişimi (dropdown, tab switch).
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Success — başarı (tamamlandı, kaydedildi).
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Error — hata (yanlış PIN, doğrulama hatası).
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Vibration — uzun (bildirim gelince).
  static Future<void> vibrate() => HapticFeedback.vibrate();
}
