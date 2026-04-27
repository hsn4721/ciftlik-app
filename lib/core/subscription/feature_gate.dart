import 'package:flutter/material.dart';
import '../design_system/ds.dart';
import '../services/auth_service.dart';
import 'subscription_constants.dart';
import 'subscription_service.dart';
import '../../features/subscription/paywall_screen.dart';

/// Feature kilitlenmiş mi kontrolü + paywall'a yönlendirme yardımcısı.
class FeatureGate {
  FeatureGate._();

  /// Kullanıcının erişimi var mı?
  static bool canAccess(SubscriptionPlan requiredPlan) {
    return SubscriptionService.instance.isUnlocked(requiredPlan);
  }

  /// Belirli bir feature'a erişmeye çalış. Erişim yoksa paywall göster ve false döner.
  /// Non-owner üye ise paywall yerine "owner ile konuş" uyarısı gösterilir.
  /// [reason] kullanıcıya gösterilecek sebep ("PDF rapor sadece Pro pakettedir")
  static Future<bool> requireAccess(
    BuildContext context,
    SubscriptionPlan requiredPlan, {
    String? featureName,
    String? reason,
  }) async {
    if (canAccess(requiredPlan)) return true;

    // Yetki kontrolü: Owner/Assistant değilse paywall yerine bilgilendir
    final user = AuthService.instance.currentUser;
    if (user != null && !user.hasFullControl && !user.isVet) {
      // Worker/Partner için paywall göstermek anlamsız — owner'a yönlendir
      await _showOwnerOnlyDialog(context, featureName);
      return false;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          highlightPlan: requiredPlan,
          featureName: featureName,
          reason: reason,
        ),
      ),
    );
    return canAccess(requiredPlan);
  }

  /// Non-owner üye Pro feature'a tıkladığında — paywall yerine bilgi diyaloğu.
  static Future<void> _showOwnerOnlyDialog(
    BuildContext context, String? featureName,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.workspace_premium_outlined, color: DsColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(featureName ?? 'Pro Özellik')),
        ]),
        content: Text(
          'Bu özellik için çiftliğinizin paketi Pro\'ya yükseltilmeli.\n\n'
          'Abonelik yönetimi yalnızca Ana Sahip yetkisinde — lütfen çiftlik '
          'sahibinizden paketi yükseltmesini talep edin.',
          style: const TextStyle(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Hayvan ekleme sınırı kontrolü.
  /// Mevcut hayvan sayısı limit'e ulaştıysa paywall göster.
  static Future<bool> checkAnimalLimit(
    BuildContext context,
    int currentCount,
  ) async {
    final plan = SubscriptionService.instance.state.plan;
    final limit = plan.animalLimit;
    if (currentCount < limit) return true;

    if (!context.mounted) return false;
    final upgraded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          highlightPlan: plan == SubscriptionPlan.starter
              ? SubscriptionPlan.family
              : SubscriptionPlan.pro,
          featureName: 'Daha Fazla Hayvan',
          reason:
              'Mevcut paketinizde maksimum $limit hayvan sınırına ulaştınız. '
              'Daha fazla hayvan eklemek için paketinizi yükseltin.',
        ),
      ),
    );
    return upgraded == true;
  }

  /// Kullanıcı sayısı sınırı kontrolü.
  static Future<bool> checkUserLimit(
    BuildContext context,
    int currentUserCount,
  ) async {
    final plan = SubscriptionService.instance.state.plan;
    final limit = plan.userLimit;
    if (currentUserCount < limit) return true;

    if (!context.mounted) return false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          highlightPlan: plan == SubscriptionPlan.starter || plan == SubscriptionPlan.none
              ? SubscriptionPlan.family
              : SubscriptionPlan.pro,
          featureName: 'Daha Fazla Kullanıcı',
          reason:
              'Mevcut paketinizde maksimum $limit kullanıcı sınırına ulaştınız. '
              'Yardımcı, ortak, veteriner veya personel eklemek için paketinizi yükseltin.',
        ),
      ),
    );
    return canAccess(plan == SubscriptionPlan.starter ? SubscriptionPlan.family : SubscriptionPlan.pro);
  }
}

/// Premium kilit overlay — kullanıcı feature'a tıkladığında üzerine bindirilir.
/// Kilit ikonu + "Pro'ya yükselt" CTA gösterir.
class PremiumLock extends StatelessWidget {
  final Widget child;
  final SubscriptionPlan requiredPlan;
  final String featureName;
  final String? reason;
  final bool showLock;

  const PremiumLock({
    super.key,
    required this.child,
    required this.requiredPlan,
    required this.featureName,
    this.reason,
    this.showLock = true,
  });

  @override
  Widget build(BuildContext context) {
    if (FeatureGate.canAccess(requiredPlan)) return child;

    return GestureDetector(
      onTap: () => FeatureGate.requireAccess(
        context, requiredPlan,
        featureName: featureName,
        reason: reason,
      ),
      child: Stack(
        children: [
          AbsorbPointer(
            child: Opacity(opacity: 0.4, child: child),
          ),
          if (showLock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: DsRadius.brMd,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [DsColors.gold, DsColors.premium],
                      ),
                      borderRadius: DsRadius.brPill,
                      boxShadow: [
                        BoxShadow(
                          color: DsColors.gold.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Pro\'ya Yükselt',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bir özelliğin yanına eklenebilen "Pro" rozeti.
class ProBadge extends StatelessWidget {
  final SubscriptionPlan tier;
  const ProBadge({super.key, this.tier = SubscriptionPlan.pro});

  @override
  Widget build(BuildContext context) {
    final label = tier == SubscriptionPlan.pro ? 'PRO'
        : tier == SubscriptionPlan.family ? 'AİLE' : 'PRO';
    final color = tier == SubscriptionPlan.pro ? DsColors.premium : DsColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
