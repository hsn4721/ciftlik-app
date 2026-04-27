import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Merkezi loglama servisi.
///
/// Geliştirmede `debugPrint` ile konsola yazar; release'de
/// `FirebaseCrashlytics.recordError` ile uzaktan toplar.
///
/// **Kullanım**:
/// ```dart
/// try { ... }
/// catch (e, st) { AppLogger.error('AnimalRepo.create', e, st); }
/// ```
///
/// `record*` metodları async değil — fire-and-forget; UI'yi bloklamaz.
/// Sentry/Datadog'a geçiş yapılırsa tek dosya içinde değiştirilebilir.
class AppLogger {
  AppLogger._();

  static bool _crashlyticsReady = false;

  /// Splash sırasında Firebase init sonrası çağrılır.
  static Future<void> init({required bool collectInDebug}) async {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode || collectInDebug);
      _crashlyticsReady = true;
    } catch (_) {
      // Test/desktop ortamlarında Crashlytics yoksa sessizce devam et
      _crashlyticsReady = false;
    }
  }

  /// Kullanıcı login olduğunda — crash raporlarına UID ekle.
  static Future<void> setUserId(String? uid) async {
    if (!_crashlyticsReady) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
    } catch (_) {}
  }

  /// Bilgi seviyesi log — sadece debug konsolu, Crashlytics'e gitmez.
  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('[INFO][$tag] $message');
  }

  /// Uyarı — debug konsolu + Crashlytics breadcrumb (non-fatal context).
  static void warn(String tag, String message) {
    if (kDebugMode) debugPrint('[WARN][$tag] $message');
    if (_crashlyticsReady) {
      try {
        FirebaseCrashlytics.instance.log('[WARN][$tag] $message');
      } catch (_) {}
    }
  }

  /// Hata — debug konsolu + Crashlytics non-fatal kaydı.
  /// `context` farklı katmanlardan zenginleştirme için (ör. 'screen=Herd').
  static void error(
    String tag,
    Object error,
    StackTrace? stack, {
    Map<String, Object?>? context,
    bool fatal = false,
  }) {
    final ctxStr = context == null || context.isEmpty
        ? ''
        : ' ctx=${context.entries.map((e) => '${e.key}:${e.value}').join(',')}';
    if (kDebugMode) {
      debugPrint('[ERR][$tag] $error$ctxStr');
      if (stack != null) debugPrint(stack.toString());
    }
    if (!_crashlyticsReady) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: '[$tag]${ctxStr.isEmpty ? '' : ctxStr}',
        fatal: fatal,
      );
    } catch (_) {}
  }
}
