import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics merkezi servisi.
///
/// Otomatik track edilen event'ler (Firebase tarafından): app_open, screen_view,
/// first_open, app_remove, in_app_purchase.
///
/// Manuel logladığımız event'ler:
///   - register_owner / register_vet / register_invitee
///   - trial_started
///   - paywall_viewed
///   - purchase_initiated / purchase_completed / purchase_failed
///   - vet_request_sent / vet_request_read
///   - invitation_sent / invitation_accepted / invitation_rejected
///   - subscription_expired
///
/// Tüm log'lar best-effort — Analytics yoksa veya hata varsa app çökmesin.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _ready = false;

  FirebaseAnalytics? get analytics => _analytics;

  /// Splash'ta Firebase init sonrası çağrılır.
  Future<void> init() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      // Debug build'de toplama kapalı — production-only veri.
      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
      _ready = true;
    } catch (e) {
      debugPrint('[AnalyticsService.init] $e');
      _ready = false;
    }
  }

  /// Kullanıcı login olduğunda — segment için UID + role.
  Future<void> setUser({required String uid, String? role}) async {
    if (!_ready || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: uid);
      if (role != null) {
        await _analytics!.setUserProperty(name: 'role', value: role);
      }
    } catch (_) {}
  }

  Future<void> clearUser() async {
    if (!_ready || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: null);
    } catch (_) {}
  }

  /// Generic event log — params lower_snake_case olmalı (Firebase kuralı).
  Future<void> log(String name, {Map<String, Object?>? params}) async {
    if (!_ready || _analytics == null) return;
    try {
      final clean = <String, Object>{};
      params?.forEach((k, v) {
        if (v != null) clean[k] = v;
      });
      await _analytics!.logEvent(name: name, parameters: clean.isEmpty ? null : clean);
    } catch (_) {}
  }

  // ─── Predefined events ─────────────────────────────────────────────

  Future<void> logRegisterOwner() => log('register_owner');
  Future<void> logRegisterVet() => log('register_vet');
  Future<void> logRegisterInvitee({String? role}) =>
      log('register_invitee', params: {'role': role});
  Future<void> logTrialStarted() => log('trial_started');
  Future<void> logPaywallViewed({String? feature}) =>
      log('paywall_viewed', params: {'feature_name': feature});
  Future<void> logPurchaseInitiated({required String productId}) =>
      log('purchase_initiated', params: {'product_id': productId});
  Future<void> logPurchaseCompleted({
    required String productId,
    String? plan,
    bool? yearly,
  }) =>
      log('purchase_completed', params: {
        'product_id': productId,
        'plan': plan,
        'yearly': yearly,
      });
  Future<void> logPurchaseFailed({required String productId, String? reason}) =>
      log('purchase_failed', params: {
        'product_id': productId,
        'reason': reason,
      });
  Future<void> logVetRequestSent({String? urgency}) =>
      log('vet_request_sent', params: {'urgency': urgency});
  Future<void> logVetRequestRead() => log('vet_request_read');
  Future<void> logInvitationSent({required String role}) =>
      log('invitation_sent', params: {'role': role});
  Future<void> logInvitationAccepted({required String role}) =>
      log('invitation_accepted', params: {'role': role});
  Future<void> logInvitationRejected({required String role}) =>
      log('invitation_rejected', params: {'role': role});
  Future<void> logSubscriptionExpired() => log('subscription_expired');

  /// Navigator observer — otomatik screen_view eventleri için.
  /// MaterialApp'a verilirken: `navigatorObservers: [AnalyticsService.instance.observer]`
  FirebaseAnalyticsObserver? get observer {
    if (_analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics!);
  }
}
