import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_constants.dart';

enum SubscriptionStatus {
  /// Hiç abonelik yok
  none,
  /// 14 gün ücretsiz deneme
  trial,
  /// Aktif abonelik
  active,
  /// Süresi dolmuş, yenilenmemiş
  expired,
  /// İptal edildi (süresi dolana kadar geçerli)
  cancelled,
  /// Ödeme alınamadı, mağaza grace period veriyor
  gracePeriod,
}

extension SubscriptionStatusX on SubscriptionStatus {
  String get label {
    switch (this) {
      case SubscriptionStatus.none:        return 'Abonelik Yok';
      case SubscriptionStatus.trial:       return 'Deneme';
      case SubscriptionStatus.active:      return 'Aktif';
      case SubscriptionStatus.expired:     return 'Süresi Doldu';
      case SubscriptionStatus.cancelled:   return 'İptal Edildi';
      case SubscriptionStatus.gracePeriod: return 'Ödeme Bekliyor';
    }
  }
}

/// Abonelik state.
///
/// **Çiftlik kullanıcıları** (owner/assistant/partner/worker) için:
///   `farms/{farmId}/subscription/current` — owner satın alır, tüm ekip yararlanır.
///
/// **Veteriner** için:
///   `users/{uid}/subscription/current` — vet user-level (multi-farm).
class SubscriptionState {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final String? productId;
  final String? platform;
  final String? transactionId;
  final String? receipt;
  /// Aboneliği satın alan kullanıcı (çiftlik düzeyi için owner uid'i).
  final String? paidByUid;

  const SubscriptionState({
    required this.plan,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.autoRenew = false,
    this.productId,
    this.platform,
    this.transactionId,
    this.receipt,
    this.paidByUid,
  });

  factory SubscriptionState.empty() => const SubscriptionState(
        plan: SubscriptionPlan.none,
        status: SubscriptionStatus.none,
      );

  /// Trial süresi dolmuş mu?
  bool isTrialExpired() {
    if (plan != SubscriptionPlan.trial) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Trial mı, kaç gün kaldı?
  int? get trialDaysLeft {
    if (plan != SubscriptionPlan.trial || expiresAt == null) return null;
    final days = expiresAt!.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  /// Kalan ömür gün cinsinden.
  int? get daysLeft {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() => {
        'plan': plan.name,
        'status': status.name,
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'autoRenew': autoRenew,
        'productId': productId,
        'platform': platform,
        'transactionId': transactionId,
        'receipt': receipt,
        'paidByUid': paidByUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory SubscriptionState.fromMap(Map<String, dynamic> m) {
    return SubscriptionState(
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == m['plan'],
        orElse: () => SubscriptionPlan.none,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => SubscriptionStatus.none,
      ),
      startedAt: (m['startedAt'] as Timestamp?)?.toDate(),
      expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
      autoRenew: m['autoRenew'] as bool? ?? false,
      productId: m['productId'] as String?,
      platform: m['platform'] as String?,
      transactionId: m['transactionId'] as String?,
      receipt: m['receipt'] as String?,
      paidByUid: m['paidByUid'] as String?,
    );
  }

  SubscriptionState copyWith({
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    bool? autoRenew,
    String? productId,
    String? platform,
    String? transactionId,
    String? receipt,
    String? paidByUid,
  }) =>
      SubscriptionState(
        plan: plan ?? this.plan,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        autoRenew: autoRenew ?? this.autoRenew,
        productId: productId ?? this.productId,
        platform: platform ?? this.platform,
        transactionId: transactionId ?? this.transactionId,
        receipt: receipt ?? this.receipt,
        paidByUid: paidByUid ?? this.paidByUid,
      );
}
