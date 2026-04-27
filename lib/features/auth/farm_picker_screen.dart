import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/invitation_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../core/subscription/subscription_service.dart';
import '../../core/subscription/subscription_constants.dart';
import '../subscription/paywall_screen.dart';
import '../../data/models/membership_model.dart';
import '../../data/models/invitation_model.dart';
import '../../data/models/user_model.dart';
import '../notifications/notification_bell_button.dart';
import '../../data/models/vet_request_model.dart';
import '../dashboard/dashboard_screen.dart';
import '../feedback/feedback_screen.dart';
import '../vet_request/vet_request_detail_screen.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';

/// Kullanıcının çiftlik seçme ekranı.
///
/// - Hiç membership yok + davet yok → "Bilgilendir owner'ı" ekranı
/// - Davet var → davetleri göster, kabul/red
/// - Membership(ler) var → çiftlik kartları + seç butonu
class FarmPickerScreen extends StatefulWidget {
  const FarmPickerScreen({super.key});

  @override
  State<FarmPickerScreen> createState() => _FarmPickerScreenState();
}

class _FarmPickerScreenState extends State<FarmPickerScreen> {
  bool _processing = false;
  StreamSubscription? _vetPushSub;

  @override
  void initState() {
    super.initState();
    _startVetPushListener();
  }

  @override
  void dispose() {
    _vetPushSub?.cancel();
    super.dispose();
  }

  /// Vet için: FarmPicker açıkken yeni gelen okunmamış talepleri push olarak gönder.
  /// Persistent dedup — daha önce push edilmişse tekrar etme.
  void _startVetPushListener() {
    final user = AuthService.instance.currentUser;
    if (user == null || !user.isVet) return;
    _vetPushSub = VetRequestService.instance.streamAllForVet(user.uid).listen((items) async {
      final prefs = await SharedPreferences.getInstance();
      final sent = prefs.getStringList('push_sent_ids') ?? [];
      bool changed = false;
      for (final r in items) {
        if (r.id == null || r.isRead) continue;
        final key = 'vet_req_${r.id}';
        if (sent.contains(key)) continue;
        sent.add(key);
        changed = true;
        NotificationService.instance.showVetRequestAlert(
          farmName: r.farmName,
          requesterName: r.requesterName,
          category: r.categoryLabel,
          urgency: r.urgencyLabel,
          notifId: r.id.hashCode.abs() % 1000000,
        );
      }
      if (changed) {
        final trimmed = sent.length > 500 ? sent.sublist(sent.length - 500) : sent;
        await prefs.setStringList('push_sent_ids', trimmed);
      }
    });
  }

  Future<void> _selectFarm(String farmId) async {
    setState(() => _processing = true);
    await AuthService.instance.setActiveFarm(farmId);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  Future<void> _acceptInvitation(InvitationModel inv) async {
    setState(() => _processing = true);
    final err = await AuthService.instance.acceptInvitation(inv);
    if (!mounted) return;
    setState(() => _processing = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${inv.farmName} üyeliğiniz aktif — aktif çiftlik olarak seçildi'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
    // Kabul sonrası dashboard'a geç (active farm otomatik set edildi)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  Future<void> _rejectInvitation(InvitationModel inv) async {
    await AuthService.instance.rejectInvitation(inv);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet reddedildi')),
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryGreen, AppColors.mediumGreen]),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF060606),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/app_icon.png', width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('ÇiftlikPRO',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const Text('v${AppConstants.appVersion}',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Text(
                  'Büyükbaş süt çiftlikleri için geliştirilmiş profesyonel yönetim uygulaması.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                const Text('ÇiftlikPRO · 2026',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('mailto:hsnduz@hotmail.com')),
                  child: const Text('hsnduz@hotmail.com',
                      style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Veteriner abonelik kontrolü — abonelik yoksa zorunlu paywall göster
    final isVetUser = user.isVet ||
        user.memberships.values.any((m) => m.isActive && m.role == AppConstants.roleVet) ||
        user.memberships.isEmpty; // Yeni kayıt vet (henüz davet kabul etmedi)
    if (isVetUser) {
      return ListenableBuilder(
        listenable: SubscriptionService.instance,
        builder: (context, _) {
          final vetActive = SubscriptionService.instance.state.plan.hasVetAccess;
          if (!vetActive) {
            return const PaywallScreen(
              vetOnly: true,
              blocking: true,
              featureName: 'Veteriner Profesyonel Aboneliği',
              reason:
                  'Çiftliklerden gelen davetler ve sağlık talepleri görüntülemek için '
                  'yıllık aboneliğiniz olmalı.',
            );
          }
          return _buildFarmPickerBody(context, user);
        },
      );
    }

    return _buildFarmPickerBody(context, user);
  }

  Widget _buildFarmPickerBody(BuildContext context, UserModel user) {
    final activeMemberships =
        user.memberships.values.where((m) => m.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ana Sayfam'),
        automaticallyImplyLeading: false,
        actions: [
          // Vet için multi-farm bildirim zili (collection group vet_requests)
          if (user.isVet) const NotificationBellButton(vetPanel: true),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onSelected: (v) {
              switch (v) {
                case 'profile':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                  break;
                case 'feedback':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()));
                  break;
                case 'about':
                  _showAbout(context);
                  break;
                case 'logout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Row(children: [
                Icon(Icons.badge_outlined, size: 18, color: AppColors.primaryGreen),
                SizedBox(width: 10),
                Text('Bilgilerimi Güncelle'),
              ])),
              PopupMenuItem(value: 'feedback', child: Row(children: [
                Icon(Icons.feedback_outlined, size: 18, color: AppColors.infoBlue),
                SizedBox(width: 10),
                Text('Geri Bildirim Gönder'),
              ])),
              PopupMenuItem(value: 'about', child: Row(children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textGrey),
                SizedBox(width: 10),
                Text('Hakkında'),
              ])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Row(children: [
                Icon(Icons.logout, size: 18, color: AppColors.errorRed),
                SizedBox(width: 10),
                Text('Çıkış Yap', style: TextStyle(color: AppColors.errorRed)),
              ])),
            ],
          ),
        ],
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<InvitationModel>>(
              stream: InvitationService.instance.streamPendingForEmail(user.email),
              builder: (_, invSnap) {
                final invitations = invSnap.data ?? const [];
                return StreamBuilder<List<VetRequestModel>>(
                  // Vet için: tüm çiftliklerden gelen talepler (collection group)
                  stream: user.isVet
                      ? VetRequestService.instance.streamAllForVet(user.uid)
                      : const Stream.empty(),
                  builder: (_, reqSnap) {
                    final allRequests = reqSnap.data ?? const [];
                    // Vet paneli: yalnızca OKUNMAMIŞ talepler gösterilir.
                    // Okundu olarak işaretlenmiş bir talep bir daha bildirim olarak çıkmaz.
                    final requests = allRequests.where((r) => !r.isRead).toList();
                    final unreadCount = requests.length;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _Greeting(name: user.displayName),
                        const SizedBox(height: 16),

                        // ─── Bildirimler (vet hesabı için — yalnızca okunmamışlar) ─
                        if (user.isVet && requests.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Bildirimler ($unreadCount yeni)',
                            icon: Icons.notifications_active,
                            color: AppColors.errorRed,
                          ),
                          const SizedBox(height: 10),
                          ...requests.take(10).map((r) => _VetRequestTile(
                                req: r,
                                onTap: () async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(builder: (_) =>
                                          VetRequestDetailScreen(req: r, asVet: true)));
                                },
                              )),
                          if (requests.length > 10)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Ve ${requests.length - 10} talep daha…',
                                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],

                        // ─── Bekleyen Davetler ──────────────────────────────
                        if (invitations.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Yeni Davetler (${invitations.length})',
                            icon: Icons.mail_outline,
                            color: AppColors.gold,
                          ),
                          const SizedBox(height: 10),
                          ...invitations.map((inv) => _InvitationTile(
                                inv: inv,
                                onAccept: () => _acceptInvitation(inv),
                                onReject: () => _rejectInvitation(inv),
                              )),
                          const SizedBox(height: 20),
                        ],

                        // ─── Çiftlikleriniz ────────────────────────────────
                        if (activeMemberships.isNotEmpty) ...[
                          const _SectionHeader(
                            title: 'Çiftlikleriniz',
                            icon: Icons.agriculture,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(height: 10),
                          ...activeMemberships.map((m) => _FarmTile(
                                membership: m,
                                isActive: user.activeFarmId == m.farmId,
                                onTap: () => _selectFarm(m.farmId),
                              )),
                        ],
                        if (activeMemberships.isEmpty &&
                            invitations.isEmpty &&
                            requests.isEmpty)
                          _NoFarmsState(email: user.email),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.mediumGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hoş geldin', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14, letterSpacing: 0.3)),
    ]);
  }
}

class _FarmTile extends StatelessWidget {
  final MembershipModel membership;
  final bool isActive;
  final VoidCallback onTap;
  const _FarmTile({required this.membership, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleLabel = AppConstants.roleLabels[membership.role] ?? membership.role;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primaryGreen : AppColors.divider,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.agriculture, color: AppColors.primaryGreen),
        ),
        title: Text(membership.farmName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.badge_outlined, size: 12, color: AppColors.primaryGreen),
            const SizedBox(width: 4),
            Text(roleLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
          ]),
        ),
        trailing: isActive
            ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
            : const Icon(Icons.chevron_right, color: AppColors.textGrey),
        onTap: onTap,
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final InvitationModel inv;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _InvitationTile({required this.inv, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final roleLabel = AppConstants.roleLabels[inv.role] ?? inv.role;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.agriculture, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(inv.farmName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(roleLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Davet eden: ${inv.invitedByName}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: const BorderSide(color: AppColors.errorRed),
                ),
                child: const Text('Reddet'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                child: const Text('Kabul Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _VetRequestTile extends StatelessWidget {
  final VetRequestModel req;
  final VoidCallback onTap;
  const _VetRequestTile({required this.req, required this.onTap});

  Color get _urgencyColor {
    switch (req.urgency) {
      case AppConstants.urgencyCritical: return AppColors.errorRed;
      case AppConstants.urgencyHigh:     return AppColors.gold;
      default:                           return AppColors.primaryGreen;
    }
  }

  IconData get _categoryIcon {
    switch (req.category) {
      case AppConstants.vetCatBirth:        return Icons.child_friendly;
      case AppConstants.vetCatCalfHealth:   return Icons.baby_changing_station;
      case AppConstants.vetCatAnimalHealth: return Icons.favorite;
      default:                              return Icons.medical_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !req.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread
              ? _urgencyColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _urgencyColor, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _urgencyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_categoryIcon, color: _urgencyColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(req.reason,
                            style: TextStyle(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(req.urgencyLabel,
                            style: TextStyle(fontSize: 10, color: _urgencyColor, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${req.farmName} • ${req.requesterName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  if (unread) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: _urgencyColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Okunmadı',
                          style: TextStyle(fontSize: 10, color: _urgencyColor, fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFarmsState extends StatelessWidget {
  final String email;
  const _NoFarmsState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textGrey),
        const SizedBox(height: 16),
        const Text('Henüz bir çiftliğe üye değilsiniz',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Size davet gönderilmesi için çiftlik sahibine $email adresini iletin. '
            'Davet aldığınızda burada görünecek.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.5),
          ),
        ),
      ]),
    );
  }
}
