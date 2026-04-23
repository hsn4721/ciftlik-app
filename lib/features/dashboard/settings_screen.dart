import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/backup_service.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import '../auth/manage_users_screen.dart';
import '../feedback/feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? _lastBackupAt;
  bool _backupLoading = false;
  bool _exportLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final t = await BackupService.instance.getLastBackupTime();
    if (mounted) setState(() => _lastBackupAt = t);
  }

  String get _backupSubtitle {
    if (_lastBackupAt == null) return 'Henüz yedekleme yapılmadı';
    final d = _lastBackupAt!;
    return 'Son: ${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isOwnerOrPartner = user?.canManageStaff ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          if (user != null) _UserProfileCard(user: user),
          const SizedBox(height: 8),

          _SettingsSection(title: 'Çiftlik', items: [
            if (isOwnerOrPartner)
              _SettingsTile(
                icon: Icons.people,
                label: 'Kullanıcı Yönetimi',
                subtitle: 'Ortak, Veteriner, Çalışan ekle',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
              ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Bildirim Ayarları',
              subtitle: 'Aşı, doğum ve stok uyarıları',
              onTap: () => _showNotificationSettings(context),
            ),
          ]),

          _SettingsSection(title: 'Veri', items: [
            _SettingsTile(
              icon: Icons.cloud_upload_outlined,
              label: 'Buluta Yedekle',
              subtitle: _backupLoading ? 'Yedekleniyor...' : _backupSubtitle,
              trailing: _backupLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                  : null,
              onTap: _backupLoading ? () {} : () => _runBackup(context),
            ),
            _SettingsTile(
              icon: Icons.file_download_outlined,
              label: 'Excel Olarak Dışa Aktar',
              subtitle: _exportLoading ? 'Hazırlanıyor...' : 'Tüm kayıtları Excel\'e aktar',
              trailing: _exportLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                  : null,
              onTap: _exportLoading ? () {} : () => _runExport(context),
            ),
          ]),

          _SettingsSection(title: 'Destek', items: [
            _SettingsTile(
              icon: Icons.feedback_outlined,
              label: 'Geri Bildirim Gönder',
              subtitle: 'Hata, öneri veya görüşlerinizi paylaşın',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
            ),
          ]),

          _SettingsSection(title: 'Uygulama', items: [
            _SettingsTile(icon: Icons.info_outline, label: 'Hakkında', onTap: () => _showAbout(context)),
            _SettingsTile(
              icon: Icons.logout,
              label: 'Çıkış Yap',
              color: AppColors.errorRed,
              onTap: () => _confirmLogout(context),
            ),
          ]),

          const SizedBox(height: 32),
          const _DeveloperCredit(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _runBackup(BuildContext context) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yedekleme için Firebase hesabınızla giriş yapın'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _backupLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    final result = await BackupService.instance.backup(
      onProgress: (msg) {
        if (mounted) setState(() {});
      },
    );

    if (!mounted) return;
    setState(() {
      _backupLoading = false;
      if (result.success) _lastBackupAt = result.lastBackupAt;
    });

    messenger.showSnackBar(SnackBar(
      content: Text(result.success ? 'Yedekleme tamamlandı!' : 'Hata: ${result.error}'),
      backgroundColor: result.success ? AppColors.primaryGreen : AppColors.errorRed,
    ));
  }

  Future<void> _runExport(BuildContext context) async {
    setState(() => _exportLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportService.instance.exportAll();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.notifications_active, color: AppColors.primaryGreen),
          SizedBox(width: 10),
          Text('Bildirim Ayarları'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NotifRow(icon: Icons.vaccines, color: AppColors.errorRed,
                label: 'Aşı Hatırlatıcıları',
                subtitle: 'Yaklaşan aşılarda bildirim'),
            const Divider(height: 1),
            _NotifRow(icon: Icons.child_friendly, color: const Color(0xFF6A1B9A),
                label: 'Doğum Hatırlatıcıları',
                subtitle: 'Doğumdan 3 gün önce bildirim'),
            const Divider(height: 1),
            _NotifRow(icon: Icons.inventory_2_outlined, color: AppColors.infoBlue,
                label: 'Stok Uyarıları',
                subtitle: 'Kritik stok seviyesinde anlık bildirim'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Bildirimler kayıt eklenirken otomatik olarak planlanır. Sistem bildirim izni verilmiş olmalıdır.',
                  style: TextStyle(fontSize: 11, color: AppColors.primaryGreen, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
              padding: const EdgeInsets.all(28),
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
                    child: Image.asset('assets/images/app_icon.png', width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('ÇiftlikPRO', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('v${AppConstants.appVersion}', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  const Text(
                    'Büyükbaş süt çiftlikleri için geliştirilmiş, offline çalışan profesyonel yönetim uygulaması.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  const Text('Geliştirici', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  const SizedBox(height: 6),
                  const Text(
                    'HASAN DUZ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('İletişim & Sosyal Medya', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ),
                  const SizedBox(height: 10),
                  _ContactRow(
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram',
                    value: '@ciftlik_pro',
                    subtitle: 'Takip edin, güncel içeriklerden haberdar olun',
                    onTap: () => launchUrl(Uri.parse('https://instagram.com/ciftlik_pro'), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: 8),
                  _ContactRow(
                    icon: Icons.mail_outline,
                    label: 'E-posta',
                    value: 'hsnduz@hotmail.com',
                    onTap: () => launchUrl(Uri.parse('mailto:hsnduz@hotmail.com')),
                  ),
                  const SizedBox(height: 8),
                  _ContactRow(
                    icon: Icons.phone_iphone,
                    label: 'WhatsApp Destek',
                    value: '0540 067 47 21',
                    subtitle: 'Bilgi ve destek için mesaj gönderin',
                    onTap: () => launchUrl(Uri.parse('https://wa.me/905400674721'), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 10),
                  const Text('© 2026 Tüm hakları saklıdır.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.signOut();
              if (!ctx.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── KULLANICI PROFİL KARTI ───────────────────────────

class _UserProfileCard extends StatelessWidget {
  final UserModel user;
  const _UserProfileCard({required this.user});

  Color get _roleColor {
    switch (user.role) {
      case AppConstants.roleOwner: return AppColors.primaryGreen;
      case AppConstants.rolePartner: return AppColors.infoBlue;
      case AppConstants.roleVet: return const Color(0xFF6A1B9A);
      default: return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_roleColor, _roleColor.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(user.roleDisplay, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ])),
      ]),
    );
  }
}

// ─── ORTAK BİLEŞENLER ────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsTile> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              return Column(children: [
                e.value,
                if (e.key < items.length - 1) const Divider(height: 1, indent: 52, color: AppColors.divider),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textDark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primaryGreen).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? AppColors.primaryGreen, size: 18),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 18),
      onTap: onTap,
    );
  }
}

class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Divider(indent: 40, endIndent: 40, color: AppColors.divider),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 8),
        const Text('ÇiftlikPRO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
      ]),
      const SizedBox(height: 6),
      const Text('@hsnduz · © 2026 Tüm hakları saklıdır.',
        style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
      const SizedBox(height: 4),
      const Text('v${AppConstants.appVersion}', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
    ]);
  }
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  const _NotifRow({required this.icon, required this.color, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ])),
        const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 18),
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  const _ContactRow({required this.icon, required this.label, required this.value, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            if (onTap != null)
              const Text('Aç →', style: TextStyle(fontSize: 10, color: AppColors.primaryGreen)),
          ]),
        ]),
      ),
    );
  }
}
