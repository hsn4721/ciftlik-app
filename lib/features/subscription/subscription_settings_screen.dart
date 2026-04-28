import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design_system/ds.dart';
import '../../core/services/auth_service.dart';
import '../../core/subscription/subscription_constants.dart';
import '../../core/subscription/subscription_service.dart';
import '../../core/subscription/subscription_state.dart';
import 'paywall_screen.dart';

/// "Aboneliğim" ayar ekranı.
class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() => _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState extends State<SubscriptionSettingsScreen> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await SubscriptionService.instance.restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Satın almalar geri yüklendi')),
    );
  }

  Future<void> _openStoreManagement() async {
    final url = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SubscriptionService.instance,
      builder: (context, _) {
        final state = SubscriptionService.instance.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Aboneliğim')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPlanCard(state),
              const SizedBox(height: 16),
              _buildLimitsCard(state),
              const SizedBox(height: 16),
              _buildActions(state),
              const SizedBox(height: 16),
              _buildLegalLinks(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(SubscriptionState state) {
    final tokens = DsTokens.of(context);
    final fmt = DateFormat('dd MMMM yyyy', 'tr_TR');

    Color planColor;
    String emoji;
    switch (state.plan) {
      case SubscriptionPlan.trial:
        planColor = DsColors.infoBlue; emoji = '🎁'; break;
      case SubscriptionPlan.starter:
        planColor = DsColors.accentGreen; emoji = '🌱'; break;
      case SubscriptionPlan.family:
        planColor = DsColors.gold; emoji = '🏠'; break;
      case SubscriptionPlan.pro:
        planColor = DsColors.premium; emoji = '💎'; break;
      default:
        planColor = tokens.textSecondary; emoji = '🔒';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [planColor.withValues(alpha: 0.15), planColor.withValues(alpha: 0.04)],
        ),
        borderRadius: DsRadius.brXl,
        border: Border.all(color: planColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mevcut Paket',
                    style: DsTypography.caption(color: tokens.textSecondary)),
                Text(state.plan.label,
                    style: DsTypography.title(color: tokens.textPrimary)
                        .copyWith(fontSize: 22)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: planColor.withValues(alpha: 0.15),
              borderRadius: DsRadius.brSm,
            ),
            child: Text(state.status.label,
                style: DsTypography.labelSmall(color: planColor)),
          ),
        ]),

        if (state.plan == SubscriptionPlan.trial && state.trialDaysLeft != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DsColors.infoBlue.withValues(alpha: 0.1),
              borderRadius: DsRadius.brMd,
              border: Border.all(color: DsColors.infoBlue.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: DsColors.infoBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trial bitimine ${state.trialDaysLeft} gün kaldı',
                  style: DsTypography.subtitle(color: DsColors.infoBlue),
                ),
              ),
            ]),
          ),
        ],

        if (state.expiresAt != null && state.plan != SubscriptionPlan.none) ...[
          const SizedBox(height: 14),
          _infoRow(
            Icons.event,
            state.plan == SubscriptionPlan.trial ? 'Trial bitiş' : 'Yenileme',
            fmt.format(state.expiresAt!),
            tokens,
          ),
        ],
        if (state.platform != null) ...[
          const SizedBox(height: 8),
          _infoRow(Icons.shop, 'Mağaza',
              state.platform == 'iOS' || Platform.isIOS ? 'App Store' : 'Google Play', tokens),
        ],
      ]),
    );
  }

  Widget _buildLimitsCard(SubscriptionState state) {
    final tokens = DsTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: DsRadius.brLg,
        border: Border.all(color: tokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Paket Limitleriniz',
            style: DsTypography.headline(color: tokens.textPrimary)),
        const SizedBox(height: 12),
        _limitRow(
          Icons.pets,
          'Hayvan Kapasitesi',
          state.plan.animalLimit > 99999 ? 'SINIRSIZ' : '${state.plan.animalLimit}',
        ),
        const SizedBox(height: 8),
        _limitRow(
          Icons.group_outlined,
          'Kullanıcı Sayısı',
          state.plan.userLimit > 1 ? '${state.plan.userLimit} kullanıcı' : 'Tek kullanıcı',
        ),
      ]),
    );
  }

  Widget _buildActions(SubscriptionState state) {
    final tokens = DsTokens.of(context);
    final user = AuthService.instance.currentUser;
    final canManageSub = user?.hasFullControl ?? false; // owner/assistant
    final isVet = user?.isVet ?? false;

    // Worker/Partner: bilgilendirici read-only kart — action button yok.
    // Vet kendi user-level aboneliğini yönetir → owner'la aynı action paneli.
    if (!canManageSub && !isVet) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: DsRadius.brLg,
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: DsColors.infoBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Çiftlik aboneliği Ana Sahip tarafından yönetilir. '
                'Paket değişikliği veya iptal için çiftlik sahibinize danışın.',
                style: TextStyle(
                  color: tokens.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: DsRadius.brLg,
        border: Border.all(color: tokens.border),
      ),
      child: Column(children: [
        if (state.plan != SubscriptionPlan.pro)
          DsListTile(
            leadingIcon: state.plan == SubscriptionPlan.trial
                ? Icons.workspace_premium
                : Icons.upgrade,
            leadingColor: DsColors.gold,
            title: state.plan == SubscriptionPlan.none
                ? 'Paketleri İncele'
                : state.plan == SubscriptionPlan.trial
                    ? 'Aboneliğe Geç'
                    : 'Paketi Yükselt',
            subtitle: state.plan == SubscriptionPlan.none
                ? 'Aboneliğe başla, tüm özellikleri keşfet'
                : state.plan == SubscriptionPlan.trial
                    ? 'Trial bitince Pro\'da kalmaya devam et'
                    : 'Daha fazla özellik için Pro\'ya geç',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
        if (state.plan != SubscriptionPlan.none && state.plan != SubscriptionPlan.trial)
          DsListTile(
            leadingIcon: Icons.settings_outlined,
            leadingColor: DsColors.infoBlue,
            title: Platform.isIOS ? 'App Store\'da Yönet' : 'Google Play\'de Yönet',
            subtitle: 'İptal et veya planı değiştir',
            onTap: _openStoreManagement,
          ),
        DsListTile(
          leadingIcon: Icons.restore,
          leadingColor: DsColors.brandGreen,
          title: 'Satın Alımları Geri Yükle',
          subtitle: 'Cihaz değişikliği sonrası abonelik geri yükleme',
          trailing: _restoring
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _restoring ? null : _restore,
        ),
      ]),
    );
  }

  Widget _buildLegalLinks() {
    final tokens = DsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication),
              child: Text('Gizlilik Politikası',
                  style: DsTypography.caption(color: tokens.textSecondary)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(AppConstants.termsOfServiceUrl),
                  mode: LaunchMode.externalApplication),
              child: Text('Kullanım Şartları',
                  style: DsTypography.caption(color: tokens.textSecondary)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Abonelikler bir sonraki yenileme tarihinden 24 saat öncesine kadar iptal '
          'edilmezse otomatik olarak yenilenir. İptal işlemleri ${Platform.isIOS ? "App Store" : "Google Play"} '
          'ayarlarından yapılır.',
          textAlign: TextAlign.center,
          style: DsTypography.caption(color: tokens.textSecondary).copyWith(height: 1.5),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, DsTokens tokens) {
    return Row(children: [
      Icon(icon, size: 18, color: tokens.textSecondary),
      const SizedBox(width: 8),
      Text(label, style: DsTypography.bodySmall(color: tokens.textSecondary)),
      const Spacer(),
      Text(value,
          style: DsTypography.subtitle(color: tokens.textPrimary)),
    ]);
  }

  Widget _limitRow(IconData icon, String label, String value) {
    final tokens = DsTokens.of(context);
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: tokens.primary.withValues(alpha: 0.1),
          borderRadius: DsRadius.brSm,
        ),
        child: Icon(icon, size: 16, color: tokens.primary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: DsTypography.body(color: tokens.textPrimary))),
      Text(value,
          style: DsTypography.label(color: tokens.primary)),
    ]);
  }
}
