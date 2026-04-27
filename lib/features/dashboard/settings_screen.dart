import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/finance_linker.dart';
import '../../core/services/payment_reminder_sync.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import '../auth/manage_users_screen.dart';
import '../auth/profile_edit_screen.dart';
import '../auth/farm_picker_screen.dart';
import '../feedback/feedback_screen.dart';
import '../settings/security_settings_screen.dart';
import '../settings/delete_account_screen.dart';
import '../subscription/subscription_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? _lastBackupAt;
  bool _backupLoading = false;
  bool _exportLoading = false;
  bool _orphanLoading = false;
  bool _reminderLoading = false;
  bool _restoreLoading = false;
  String? _restoreProgress;
  int? _orphanCount;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
    _countOrphans();
  }

  Future<void> _loadLastBackup() async {
    final t = await BackupService.instance.getLastBackupTime();
    if (mounted) setState(() => _lastBackupAt = t);
  }

  Future<void> _countOrphans() async {
    final orphans = await FinanceLinker.instance.findOrphans();
    if (mounted) setState(() => _orphanCount = orphans.length);
  }

  String get _orphanSubtitle {
    if (_orphanLoading) return 'Taranıyor...';
    if (_orphanCount == null) return 'Kaynağı silinmiş finans kayıtlarını bul ve temizle';
    if (_orphanCount == 0) return 'Tüm finans kayıtları kaynaklarıyla eşleşiyor';
    return '$_orphanCount öksüz kayıt bulundu — temizlemek için dokun';
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
    final canManageUsers = user?.canManageUsers ?? false;
    final canManageBackup = user?.canManageBackup ?? false;
    final isVet = user?.isVet ?? false;
    // Çoklu çiftlik ve çiftlikten ayrılma yalnızca Veteriner içindir.
    // Yardımcı/Ortak/Personel tek çiftlikte çalışır — ana sayfaları bağlı oldukları
    // çiftliktir; ayrılma/çiftlik değiştirme akışlarına ihtiyaçları yok.
    final canLeaveFarm = user != null &&
        user.activeFarmId != null &&
        isVet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          if (user != null) _UserProfileCard(user: user),
          const SizedBox(height: 8),

          // Profil bölümü — Aboneliğim sadece owner/assistant/vet için.
          // Worker/Partner abonelik yönetimine erişmez (Ana Sahip yönetir).
          _SettingsSection(title: 'Profil', items: [
            _SettingsTile(
              icon: Icons.badge_outlined,
              label: 'Bilgilerimi Güncelle',
              subtitle: 'Ad, soyad ve hesap bilgileriniz',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
            ),
            if ((user?.hasFullControl ?? false) || isVet)
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Aboneliğim',
                subtitle: 'Mevcut paket, yenileme tarihi, yönet',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionSettingsScreen())),
              ),
            _SettingsTile(
              icon: Icons.security_outlined,
              label: 'Güvenlik',
              subtitle: 'PIN, biyometri, otomatik kilit, veri maskeleme',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
            ),
          ]),

          // Çoklu çiftlik bölümü yalnızca Veteriner için — birden fazla çiftliğe
          // hizmet verebilir, davet kabul eder, çiftlikler arası geçiş yapar.
          if (isVet)
            _SettingsSection(title: 'Çiftlikler', items: [
              _SettingsTile(
                icon: Icons.swap_horiz,
                label: 'Çiftlikler ve Davetler',
                subtitle: 'Çiftlik değiştir, bekleyen davetleri gör',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FarmPickerScreen())),
              ),
              if (canLeaveFarm)
                _SettingsTile(
                  icon: Icons.logout,
                  label: 'Bu Çiftlikten Ayrıl',
                  subtitle: 'Sadece mevcut çiftliğin üyeliğinden çık',
                  color: AppColors.errorRed,
                  onTap: () => _confirmLeaveFarm(context, user),
                ),
            ]),

          _SettingsSection(title: 'Çiftlik', items: [
            if (canManageUsers)
              _SettingsTile(
                icon: Icons.people,
                label: 'Kullanıcı Yönetimi',
                subtitle: 'Yardımcı, Ortak, Veteriner, Personel ekle',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
              ),
            // Bildirim Ayarları vet'e GÖSTERİLMEZ (çiftlik seviyesi ayar)
            if (!isVet)
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Bildirim Ayarları',
                subtitle: 'Aşı, doğum, stok ve ödeme uyarıları',
                onTap: () => _showNotificationSettings(context),
              ),
          ]),

          _SettingsSection(title: 'Veri', items: [
            if (canManageBackup)
              _SettingsTile(
                icon: Icons.cloud_upload_outlined,
                label: 'Buluta Yedekle',
                subtitle: _backupLoading ? 'Yedekleniyor...' : _backupSubtitle,
                trailing: _backupLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                    : null,
                onTap: _backupLoading ? () {} : () => _runBackup(context),
              ),
            if (canManageBackup)
              _SettingsTile(
                icon: Icons.cloud_download_outlined,
                label: 'Buluttan Geri Yükle',
                subtitle: _restoreLoading
                    ? (_restoreProgress ?? 'Geri yükleniyor...')
                    : 'Yerel verileri bulutla değiştir',
                trailing: _restoreLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                    : null,
                onTap: _restoreLoading ? () {} : () => _runRestore(context),
              ),
            if (canManageBackup)
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

          if (canManageBackup)
            _SettingsSection(title: 'Finans Bakım', items: [
            _SettingsTile(
              icon: Icons.cleaning_services_outlined,
              label: 'Öksüz Kayıtları Temizle',
              subtitle: _orphanSubtitle,
              trailing: _orphanLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                  : (_orphanCount != null && _orphanCount! > 0)
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$_orphanCount',
                              style: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.w800)),
                        )
                      : null,
              onTap: _orphanLoading ? () {} : () => _runOrphanCleanup(context),
            ),
            _SettingsTile(
              icon: Icons.notifications_active_outlined,
              label: 'Ödeme Hatırlatıcılarını Yenile',
              subtitle: _reminderLoading
                  ? 'Planlanıyor...'
                  : 'Bekleyen ödemeler için bildirimleri yeniden kur',
              trailing: _reminderLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                  : null,
              onTap: _reminderLoading ? () {} : () => _reschedulePaymentReminders(context),
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
              icon: Icons.devices_other,
              label: 'Tüm Cihazlardan Çıkış',
              subtitle: 'Her yerde açık oturumları sonlandır',
              color: AppColors.errorRed,
              onTap: () => _confirmSignOutAllDevices(context),
            ),
            _SettingsTile(
              icon: Icons.logout,
              label: 'Çıkış Yap',
              color: AppColors.errorRed,
              onTap: () => _confirmLogout(context),
            ),
          ]),

          _SettingsSection(title: 'Tehlikeli Bölge', items: [
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              label: 'Hesabı Sil',
              subtitle: 'KVKK uyumu — tüm verileriniz kalıcı silinir',
              color: AppColors.errorRed,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
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

  Future<void> _confirmLeaveFarm(BuildContext context, UserModel user) async {
    final membership = user.activeMembership;
    if (membership == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
          SizedBox(width: 10),
          Expanded(child: Text('Çiftlikten Ayrıl')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${membership.farmName}" çiftliğinin üyeliğinden çıkmak üzeresiniz.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Bu işlem sonrası bu çiftliğin verilerine erişemezsiniz. '
                  'Yeniden üye olmanız için Ana Sahip\'in sizi tekrar davet etmesi gerekir.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final err = await AuthService.instance.leaveFarm(membership.farmId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${membership.farmName}" çiftliğinden ayrıldınız'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );

    // Başka aktif çiftliği var mı?
    final refreshed = AuthService.instance.currentUser;
    if (refreshed?.activeFarmId != null) {
      // Otomatik olarak başka çiftliğe geçti — ayarları kapat, dashboard'a dön
      Navigator.pop(context);
    } else {
      // Hiç aktif çiftliği yok → FarmPicker'a
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FarmPickerScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _runRestore(BuildContext context) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geri yükleme için oturum açın'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    // İki aşamalı onay — işlem geri alınamaz
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: AppColors.errorRed),
          SizedBox(width: 10),
          Text('Geri Yükleme'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu işlem YEREL verileri silip bulut yedeğiyle değiştirir. '
              'Son yedekten sonra eklediğiniz yerel kayıtlar kaybolur.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Önce "Buluta Yedekle" ile güncel yedek aldığınızdan emin olun.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _restoreLoading = true;
      _restoreProgress = 'Başlatılıyor...';
    });
    final messenger = ScaffoldMessenger.of(context);

    final result = await BackupService.instance.restore(
      onProgress: (msg) {
        if (mounted) setState(() => _restoreProgress = msg);
      },
    );

    if (!mounted) return;
    setState(() {
      _restoreLoading = false;
      _restoreProgress = null;
    });

    if (result.success) {
      final total = result.counts.values.fold(0, (s, c) => s + c);
      messenger.showSnackBar(SnackBar(
        content: Text('Geri yükleme tamamlandı — $total kayıt yüklendi'),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 4),
      ));
      // Orphan sayısı ve diğer bakım sayaçları değişmiş olabilir
      _countOrphans();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('Geri yükleme başarısız: ${result.error ?? "bilinmeyen hata"}'),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Future<void> _runOrphanCleanup(BuildContext context) async {
    setState(() => _orphanLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final orphans = await FinanceLinker.instance.findOrphans();
    if (!mounted) return;

    if (orphans.isEmpty) {
      setState(() { _orphanLoading = false; _orphanCount = 0; });
      messenger.showSnackBar(const SnackBar(
        content: Text('Öksüz kayıt bulunamadı — her şey temiz'),
        backgroundColor: AppColors.primaryGreen,
      ));
      return;
    }

    setState(() => _orphanLoading = false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Öksüz Kayıtlar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${orphans.length} finans kaydının kaynak modüldeki karşılığı silinmiş.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: orphans.take(8).map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${f.category} — ₺${f.amount.toStringAsFixed(2)} (${f.sourceLabel})',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  )).toList(),
                ),
              ),
            ),
            if (orphans.length > 8)
              Text('... ve ${orphans.length - 8} kayıt daha',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const SizedBox(height: 8),
            const Text('Temizlensin mi?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _orphanLoading = true);
    final deleted = await FinanceLinker.instance.cleanOrphans();
    if (!mounted) return;
    setState(() { _orphanLoading = false; _orphanCount = 0; });
    messenger.showSnackBar(SnackBar(
      content: Text('$deleted öksüz kayıt temizlendi'),
      backgroundColor: AppColors.primaryGreen,
    ));
  }

  Future<void> _reschedulePaymentReminders(BuildContext context) async {
    setState(() => _reminderLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final count = await PaymentReminderSync.rescheduleAll();
    if (!mounted) return;
    setState(() => _reminderLoading = false);
    messenger.showSnackBar(SnackBar(
      content: Text(count == 0
          ? 'Bekleyen ödeme yok — planlanacak hatırlatıcı bulunmadı'
          : '$count ödeme hatırlatıcısı yeniden planlandı'),
      backgroundColor: AppColors.primaryGreen,
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
            const Divider(height: 1),
            _NotifRow(icon: Icons.payments_outlined, color: AppColors.gold,
                label: 'Ödeme Hatırlatıcıları',
                subtitle: 'Vadeli ödemelerde 1 gün önce + ödeme günü bildirim'),
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => _AboutDialogContent(),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
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

  Future<void> _confirmSignOutAllDevices(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.devices_other, color: AppColors.errorRed),
          SizedBox(width: 10),
          Text('Tüm Cihazlardan Çıkış'),
        ]),
        content: const Text(
          'Bu hesaba ait tüm cihazlarda oturum sonlandırılacak. Telefonunuz, tabletiniz '
          've diğer cihazlarda yeniden giriş yapmanız gerekecek.\n\n'
          'Devam etmek istiyor musunuz?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Tümünde Çıkış Yap',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await AuthService.instance.signOutAllDevices();
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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

/// Premium "Hakkında" dialog'u — tam ekran dialog, üste kadar çıkmaz,
/// taşma yok, iletişim satırları netkart halinde dizilir.
class _AboutDialogContent extends StatelessWidget {
  const _AboutDialogContent();

  static const _email = 'ciftlikpro@ciftlikpro.net';
  static const _website = 'www.ciftlikpro.net';
  static const _whatsapp = '0540 067 47 21';
  static const _instagram = '@ciftlik_pro';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Hero Header ─────────────────────────
              _AboutHero(),

              // ─── Content — kompakt, scroll gerektirmez ────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Açıklama (compact)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Büyükbaş süt çiftlikleri için profesyonel yönetim uygulaması.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B73),
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Telif Hakkı + Geliştirici (tek kart) ─
                      _CopyrightCard(),

                      const SizedBox(height: 12),

                      // Bölüm başlığı
                      const _SectionLabel(text: 'İLETİŞİM'),
                      const SizedBox(height: 8),

                      // ─── İletişim Kartları (compact) ──────────
                      _ContactTile(
                        icon: Icons.language_rounded,
                        iconBg: const Color(0xFF1565C0),
                        label: 'Web Sitesi',
                        value: _website,
                        onTap: () => launchUrl(
                          Uri.parse('https://ciftlikpro.net'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ContactTile(
                        icon: Icons.mail_outline_rounded,
                        iconBg: AppColors.primaryGreen,
                        label: 'E-posta',
                        value: _email,
                        onTap: () => launchUrl(Uri.parse('mailto:$_email')),
                      ),
                      const SizedBox(height: 6),
                      _ContactTile(
                        assetImage: 'assets/images/whatsapp.jpg',
                        iconBg: const Color(0xFF25D366),
                        label: 'WhatsApp Destek',
                        value: _whatsapp,
                        onTap: () => launchUrl(
                          Uri.parse('https://wa.me/905400674721'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ContactTile(
                        assetImage: 'assets/images/instagram_icon.png',
                        iconBg: const Color(0xFFE4405F),
                        label: 'Instagram',
                        value: _instagram,
                        onTap: () => launchUrl(
                          Uri.parse('https://instagram.com/ciftlik_pro'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Kapat butonu ───────────────────────
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEDEDF0), width: 0.5)),
                ),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        'Kapat',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero header — gradient + logo + ad + versiyon (compact).
class _AboutHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A2E0F),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF4CD964).withValues(alpha: 0.25),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Row(children: [
            // Logo — küçültüldü
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CD964).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 58, height: 58,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ÇiftlikPRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Telif hakkı + Geliştirici — tek kompakt satır.
class _CopyrightCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.06),
            AppColors.primaryGreen.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryGreen,
            size: 18,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Telif Hakkı',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9A9AA3),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ÇiftlikPRO · 2026',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Geliştirici: Hasan DUZ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9A9AA3),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Premium iletişim satırı — label + value, icon solda kare, arrow sağda.
/// Uzun değerler düzgün ellipsis ile kesilir, üst üste binmez.
/// [icon] veya [assetImage] birinden biri verilir (asset varsa image kullanılır).
class _ContactTile extends StatelessWidget {
  final IconData? icon;
  final String? assetImage;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactTile({
    this.icon,
    this.assetImage,
    required this.iconBg,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEDF0), width: 0.5),
          ),
          child: Row(children: [
            // Logo — asset varsa clipped image, yoksa icon
            assetImage != null
                ? Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: iconBg.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        assetImage!,
                        width: 40, height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: iconBg.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A9AA3),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D1D1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: Color(0xFFB0B0B8),
            ),
          ]),
        ),
      ),
    );
  }
}
