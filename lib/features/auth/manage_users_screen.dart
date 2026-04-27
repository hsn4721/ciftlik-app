import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/subscription/feature_gate.dart';
import '../../data/models/user_model.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<UserModel> _users = [];
  Map<String, Map<String, int>> _quotas = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      AuthService.instance.getFarmUsers(),
      AuthService.instance.getAllRoleQuotas(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = results[0] as List<UserModel>;
      _quotas = results[1] as Map<String, Map<String, int>>;
      _loading = false;
    });
  }

  Future<void> _addUser() async {
    // Mevcut kullanıcı sayısı paket limitini aştıysa paywall göster
    final activeCount = _users.where((u) => u.isActive).length;
    if (!await FeatureGate.checkUserLimit(context, activeCount)) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddUserSheet(),
    );
    _load();
  }

  Future<void> _changeRole(UserModel user) async {
    final current = AuthService.instance.currentUser;
    if (current == null || !current.canManageUsers) return;
    if (user.uid == current.uid) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rol Değiştir'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.inviteableRoles.map((r) => RadioListTile<String>(
              value: r,
              groupValue: user.role,
              title: Text(AppConstants.roleLabels[r] ?? r, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(AppConstants.roleDescriptions[r] ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              onChanged: (v) => Navigator.pop(context, v),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal'))],
      ),
    );

    if (selected != null && selected != user.role) {
      await AuthService.instance.updateUserRole(user.uid, selected);
      _load();
    }
  }

  Future<void> _deactivate(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kullanıcıyı Devre Dışı Bırak'),
        content: Text(
          '${user.displayName} artık bu çiftliğe giremeyecek ama kaydı korunur. '
          'İstediğinizde tekrar aktifleştirebilirsiniz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Devre Dışı Bırak'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.deactivateUser(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName} devre dışı bırakıldı'),
              backgroundColor: AppColors.primaryGreen),
        );
      }
      _load();
    }
  }

  Future<void> _activate(UserModel user) async {
    await AuthService.instance.activateUser(user.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} yeniden aktifleştirildi'),
            backgroundColor: AppColors.primaryGreen),
      );
    }
    _load();
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_forever, color: AppColors.errorRed),
          SizedBox(width: 10),
          Text('Kullanıcıyı Sil'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.displayName} kalıcı olarak silinecek. Bu işlem geri alınamaz.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.25)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: AppColors.errorRed, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Kalıcı silme yerine "Devre Dışı" seçeneği de var — '
                  'o kullanıcı gelecekte dönebilir.',
                  style: TextStyle(fontSize: 11, color: AppColors.errorRed, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Kalıcı Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final warn = await AuthService.instance.deleteUser(user.uid);
        if (!mounted) return;
        if (warn == null) {
          // Tam başarı — Firebase'de hiç iz yok
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} kalıcı silindi'),
              backgroundColor: AppColors.primaryGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Kısmi başarı — UI'dan gitti ama users doc kaldı
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.gold),
                SizedBox(width: 10),
                Expanded(child: Text('Kısmi Silme')),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user.displayName} çiftlikten çıkarıldı, ancak Firebase\'de '
                    'kullanıcı dokümanı kaldı.',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      warn,
                      style: const TextStyle(fontSize: 11, height: 1.5,
                          fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Çözüm: Terminal\'de bu komutu çalıştırın, '
                    'sonra silmeyi tekrar deneyin.',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silinirken hata: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
      _load();
    }
  }

  /// Ad/soyad + telefon + notlar düzenleme diyaloğu.
  /// Email Firebase Auth'a bağlı olduğu için client-side değiştirilemez;
  /// değiştirmek için kullanıcı silinip yeniden davet edilmelidir.
  Future<void> _editInfo(UserModel user) async {
    final nameCtrl = TextEditingController(text: user.displayName);
    final phoneCtrl = TextEditingController(
        text: user.memberships[user.activeFarmId]?.farmName == null ? '' : '');
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bilgileri Düzenle — ${user.displayName}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad *',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon (opsiyonel)',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notlar (opsiyonel)',
                prefixIcon: Icon(Icons.notes, color: AppColors.textGrey),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.email_outlined, size: 14, color: AppColors.infoBlue),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  '${user.email}\nE-posta değiştirilemez. Değiştirmek için kullanıcıyı silip yeniden davet edin.',
                  style: const TextStyle(fontSize: 10, color: AppColors.infoBlue, height: 1.3),
                )),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad Soyad boş olamaz')),
      );
      return;
    }
    final err = await AuthService.instance.updateMemberInfo(
      uid: user.uid,
      displayName: name,
      phone: phoneCtrl.text,
      notes: notesCtrl.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Bilgiler güncellendi'),
        backgroundColor: err != null ? AppColors.errorRed : AppColors.primaryGreen,
      ),
    );
    if (err == null) _load();
  }

  /// Kullanıcıya şifre sıfırlama e-postası gönder (Firebase Auth).
  Future<void> _sendPasswordReset(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Şifre Sıfırlama E-postası'),
        content: Text(
          '${user.email} adresine şifre sıfırlama e-postası gönderilsin mi?\n\n'
          'Kullanıcı gelen e-postadaki bağlantıyla yeni şifresini belirler.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await AuthService.instance.sendPasswordResetForMember(user.email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '${user.email} adresine sıfırlama bağlantısı gönderildi'),
        backgroundColor: err != null ? AppColors.errorRed : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    // Kullanıcı yönetimi yalnızca Ana Sahip'e açık (Yardımcı dahil değil)
    final canManage = currentUser?.canManageUsers ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _addUser,
              tooltip: 'Kullanıcı Ekle',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (canManage) _QuotaPanel(quotas: _quotas),
              Expanded(
                child: _users.isEmpty
                    ? const Center(child: Text('Kullanıcı bulunamadı'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _users.length,
                        itemBuilder: (_, i) {
                          final user = _users[i];
                          final isSelf = user.uid == currentUser?.uid;
                          return _UserCard(
                            user: user,
                            isSelf: isSelf,
                            isOwner: canManage,
                            onChangeRole: () => _changeRole(user),
                            onDeactivate: () => _deactivate(user),
                            onActivate: () => _activate(user),
                            onDelete: () => _deleteUser(user),
                            onEditInfo: () => _editInfo(user),
                            onResetPassword: () => _sendPasswordReset(user),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

/// Rol bazlı kota paneli — Ana Sahip için kullanıcı yönetimi ekranının üst
/// kısmında gösterilir. Her rol için "kullanılan/maksimum" bilgisi, dolu
/// olduğunda kırmızı vurguyla.
class _QuotaPanel extends StatelessWidget {
  final Map<String, Map<String, int>> quotas;
  const _QuotaPanel({required this.quotas});

  static const _roleOrder = [
    AppConstants.roleAssistant,
    AppConstants.rolePartner,
    AppConstants.roleWorker,
    AppConstants.roleVet,
  ];

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleAssistant: return const Color(0xFF2E7D32);
      case AppConstants.rolePartner:   return AppColors.infoBlue;
      case AppConstants.roleVet:       return const Color(0xFF6A1B9A);
      case AppConstants.roleWorker:    return const Color(0xFFEF6C00);
      default: return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toplam: 1 (owner) + tüm quotas.max toplamı
    int totalUsed = 1; // owner dahil
    int totalMax = 1;
    for (final q in quotas.values) {
      totalUsed += q['used'] ?? 0;
      totalMax += q['max'] ?? 0;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.group_outlined, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Kullanıcı Kotası',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$totalUsed / $totalMax',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                )),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Ana Sahip dahil toplam maksimum kullanıcı. Her rol için ayrı kota uygulanır.',
          style: TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
        const SizedBox(height: 10),
        // Ana Sahip rozet (her zaman 1/1)
        Row(children: [
          Expanded(child: _QuotaRow(
            label: 'Ana Sahip',
            used: 1, max: 1,
            color: AppColors.primaryGreen,
          )),
        ]),
        const SizedBox(height: 6),
        ..._roleOrder.map((role) {
          final q = quotas[role] ?? const {'used': 0, 'max': 0};
          final label = AppConstants.roleLabels[role] ?? role;
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _QuotaRow(
              label: label,
              used: q['used'] ?? 0,
              max: q['max'] ?? 0,
              color: _roleColor(role),
            ),
          );
        }),
      ]),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  final String label;
  final int used;
  final int max;
  final Color color;
  const _QuotaRow({
    required this.label,
    required this.used,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = max > 0 && used >= max;
    final ratio = max == 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final barColor = isFull ? AppColors.errorRed : color;
    return Row(children: [
      SizedBox(
        width: 80,
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.divider.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 42,
        child: Text(
          '$used / $max',
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isFull ? AppColors.errorRed : AppColors.textDark,
          ),
        ),
      ),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final bool isOwner;
  final VoidCallback onChangeRole;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback onEditInfo;
  final VoidCallback onResetPassword;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.isOwner,
    required this.onChangeRole,
    required this.onDeactivate,
    required this.onActivate,
    required this.onDelete,
    required this.onEditInfo,
    required this.onResetPassword,
  });

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleOwner:     return AppColors.primaryGreen;
      case AppConstants.roleAssistant: return const Color(0xFF2E7D32);
      case AppConstants.rolePartner:   return AppColors.infoBlue;
      case AppConstants.roleVet:       return const Color(0xFF6A1B9A);
      case AppConstants.roleWorker:    return const Color(0xFFEF6C00);
      default:                         return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    final inactive = !user.isActive;

    return Opacity(
      opacity: inactive ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: inactive ? AppColors.textGrey : color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
          title: Row(children: [
            Expanded(
              child: Text(
                user.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: inactive ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isSelf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('Siz', style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
              ),
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            Row(children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(user.roleDisplay, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (inactive) ...[
                const SizedBox(width: 6),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PASİF',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ]),
          trailing: isOwner && !isSelf
              ? PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'info') onEditInfo();
                    if (v == 'password') onResetPassword();
                    if (v == 'role') onChangeRole();
                    if (v == 'deactivate') onDeactivate();
                    if (v == 'activate') onActivate();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (user.isActive) ...[
                      const PopupMenuItem(value: 'info',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryGreen),
                          SizedBox(width: 8),
                          Text('Bilgileri Düzenle'),
                        ])),
                      const PopupMenuItem(value: 'password',
                        child: Row(children: [
                          Icon(Icons.lock_reset, size: 16, color: AppColors.infoBlue),
                          SizedBox(width: 8),
                          Text('Şifre Sıfırla'),
                        ])),
                      const PopupMenuItem(value: 'role',
                        child: Row(children: [
                          Icon(Icons.swap_horiz, size: 16, color: AppColors.primaryGreen),
                          SizedBox(width: 8),
                          Text('Rol Değiştir'),
                        ])),
                      const PopupMenuItem(value: 'deactivate',
                        child: Row(children: [
                          Icon(Icons.person_off_outlined, color: AppColors.gold, size: 16),
                          SizedBox(width: 8),
                          Text('Devre Dışı Bırak'),
                        ])),
                    ] else ...[
                      const PopupMenuItem(value: 'activate',
                        child: Row(children: [
                          Icon(Icons.person_add_alt_1, color: AppColors.primaryGreen, size: 16),
                          SizedBox(width: 8),
                          Text('Tekrar Aktifleştir'),
                        ])),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_forever, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Kalıcı Sil', style: TextStyle(color: Colors.red)),
                      ])),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

// ─── ADD USER SHEET ───────────────────────────────────

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet();

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = AppConstants.roleWorker;
  bool _obscurePass = true;
  bool _saving = false;
  String? _error;

  /// Vet rolünde şifre yok (kendi kaydı olur)
  bool get _needsPassword => _role != AppConstants.roleVet;

  // 4 davet edilebilir rol (owner hariç — owner tek olur, yeni davette verilemez)
  List<Map<String, String>> get _roleOptions => AppConstants.inviteableRoles
      .map((r) => {
            'value': r,
            'label': AppConstants.roleLabels[r] ?? r,
            'desc': AppConstants.roleDescriptions[r] ?? '',
          })
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    // Vet → davet akışı (isim + email yeter)
    if (_role == AppConstants.roleVet) {
      final res = await AuthService.instance.inviteVet(
        email: _emailCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!res.success) {
        setState(() => _error = res.error);
        return;
      }
      // Başarılı — owner'a geri bildirim
      if (res.isRegistered) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res.email} veteriner olarak kayıtlı — bildirim gönderildi'),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Vet henüz kayıtlı değil — mailto akışı
        await _showSendEmailDialog(res);
      }
      return;
    }

    // Yardımcı/Ortak/Personel → doğrudan hesap oluştur (şifre ile)
    final result = await AuthService.instance.inviteUserWithPassword(
      email: _emailCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role: _role,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameCtrl.text.trim()} eklendi — şifreyi kullanıcıya iletin'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  /// Vet kayıtlı değilse: owner'a dialog göster, onaylarsa mailto intent açılır.
  Future<void> _showSendEmailDialog(VetInvitationResult res) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.infoBlue),
          SizedBox(width: 10),
          Text('Veteriner Kayıtlı Değil'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${res.email} adresi henüz ÇiftlikPRO\'ya kayıtlı değil.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'Davet mesajınız için e-posta uygulamanız açılacak. Göndererek veterinere '
              'uygulamayı indirip veteriner kaydı olması isteneceğini bildirebilirsiniz. '
              'Kayıt olduktan sonra davetiniz uygulamada görünecek.',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('E-posta Gönder'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _launchInvitationEmail(res);
      if (!mounted) return;
      Navigator.pop(context); // Add user sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Davet kaydı oluşturuldu. Veteriner uygulamaya ${res.email} ile kaydolunca davet görünecek.'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _launchInvitationEmail(VetInvitationResult res) async {
    const subject = 'ÇiftlikPRO - Veteriner Davetiniz';
    final body = '''Merhaba,

${res.ownerName}, "${res.farmName}" çiftliği için sizi ÇiftlikPRO uygulamasına veteriner olarak davet ediyor.

Daveti kabul etmek için:
1) ÇiftlikPRO uygulamasını telefonunuza indirin (App Store / Play Store).
2) "Veteriner Kaydı" seçeneğiyle, bu e-posta adresinizle (${res.email}) hesap oluşturun.
3) Uygulamaya girdiğinizde bekleyen davetinizi göreceksiniz; kabul ederek "${res.farmName}" çiftliğine bağlanırsınız.

Soru sormak için bu e-postayı yanıtlayabilirsiniz.

İyi çalışmalar,
${res.ownerName}''';

    final uri = Uri(
      scheme: 'mailto',
      path: res.email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('E-posta uygulaması açılamadı: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Yeni Kullanıcı Ekle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Ad Soyad *'),
                validator: (v) => v == null || v.isEmpty ? 'Ad soyad giriniz' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'E-posta giriniz';
                  if (!v.contains('@')) return 'Geçersiz e-posta';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Rol-bazlı açıklama
              if (_needsPassword) ...[
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Şifre *',
                    helperText: 'Bu şifreyi kullanıcıya iletin',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Şifre giriniz';
                    if (v.length < 6) return 'En az 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.infoBlue),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Kullanıcı oluşturuluyor — belirlediğiniz şifreyi kullanıcıya iletin. '
                      'Kullanıcı bu şifre ile giriş yapıp çiftliğe direkt bağlanır.',
                      style: TextStyle(fontSize: 11, color: AppColors.infoBlue, height: 1.4),
                    )),
                  ]),
                ),
              ] else ...[
                // Veteriner akışı — şifre yok
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3)),
                  ),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.medical_services, size: 16, color: Color(0xFF6A1B9A)),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Veteriner Davet Akışı:\n'
                      '• Şifre GİRMEYİN — veteriner kendi hesabını oluşturur.\n'
                      '• Eğer sistemde kayıtlıysa: uygulamada bildirim gider.\n'
                      '• Kayıtlı değilse: size e-posta uygulaması açılır, davet maili gönderirsiniz.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6A1B9A), height: 1.5),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Kullanıcı Rolü', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ..._roleOptions.map((opt) => GestureDetector(
                onTap: () => setState(() => _role = opt['value']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _role == opt['value'] ? AppColors.primaryGreen.withValues(alpha: 0.08) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _role == opt['value'] ? AppColors.primaryGreen : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(children: [
                    Radio<String>(
                      value: opt['value']!,
                      groupValue: _role,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(opt['desc']!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ])),
                  ]),
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Kullanıcı Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}
