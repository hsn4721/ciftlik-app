import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/farm_task_model.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/models/farm_member_model.dart';
import '../../data/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/farm_task_service.dart';
import '../../core/services/leave_request_service.dart';
import '../../core/services/farm_member_service.dart';
import '../../core/services/finance_linker.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/masked_amount.dart';
import '../../shared/widgets/undo_snackbar.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    final u = AuthService.instance.currentUser;
    // Worker: sadece Görevler + İzinler sekmeleri (personel listesi yok)
    // Owner/Assistant/Partner/Vet: Personel + Görevler + İzinler
    final tabCount = (u?.isWorker ?? false) ? 2 : 3;
    _tab = TabController(length: tabCount, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// FarmMember için maaş ödeme — tutar ve not sorulur, finansa kaydedilir.
  Future<void> _paySalary(FarmMember m) async {
    final now = DateTime.now();
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final amountCtrl = TextEditingController(
        text: m.monthlySalary != null ? m.monthlySalary!.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Maaş Öde — ${m.displayName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (m.monthlySalary != null) ...[
            const SizedBox(height: 4),
            Text('Kayıtlı maaş: ₺${fmt.format(m.monthlySalary!)} / ay',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Ödeme Tutarı (₺)',
              prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primaryGreen),
              suffixText: '₺',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: InputDecoration(
              labelText: 'Not (opsiyonel)',
              hintText: '${now.month}. ay maaşı',
              prefixIcon: const Icon(Icons.notes, color: AppColors.textGrey),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ödemeyi Kaydet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );

    if (confirmed == true) {
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) return;
      final today = now.toIso8601String().split('T').first;
      final note = notesCtrl.text.trim().isEmpty
          ? '${now.month}. ay maaşı'
          : notesCtrl.text.trim();
      final result = await FinanceLinker.instance.link(
        source: AppConstants.srcSalary,
        sourceRef: 'staff_salary:${m.uid}:${now.toIso8601String()}',
        type: AppConstants.expense,
        category: AppConstants.expenseLabor,
        amount: amount,
        date: today,
        description: '${m.displayName} maaş ödemesi — ${m.roleLabel}',
        notes: note,
      );
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₺${fmt.format(amount)} maaş ödemesi finansa kaydedildi'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maaş kaydedilemedi'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  /// Aylık maaş ayarı (member doc'taki monthlySalary alanı).
  Future<void> _setSalary(FarmMember m) async {
    final ctrl = TextEditingController(
        text: m.monthlySalary != null ? m.monthlySalary!.toStringAsFixed(2) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Maaş Ayarla — ${m.displayName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Aylık Maaş (₺)',
            prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryGreen),
            helperText: 'Boş bırakılırsa maaş kaydı silinir',
          ),
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
    final txt = ctrl.text.trim().replaceAll(',', '.');
    final val = txt.isEmpty ? null : double.tryParse(txt);
    if (txt.isNotEmpty && (val == null || val < 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz tutar')),
      );
      return;
    }
    final err = await FarmMemberService.instance.updateSalary(
      farmId: m.farmId, uid: m.uid, monthlySalary: val,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? (val == null ? 'Maaş kaydı kaldırıldı' : 'Maaş güncellendi')),
        backgroundColor: err != null ? AppColors.errorRed : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.currentUser;
    final isWorker = u?.isWorker ?? false;
    final canManage = u?.canManageStaff ?? false;

    final tabs = <Tab>[
      if (!isWorker) const Tab(text: 'Personel'),
      const Tab(text: 'Görevler'),
      const Tab(text: 'İzinler'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isWorker ? 'Görevlerim' : 'Personel & Görevler'),
        bottom: TabBar(controller: _tab, tabs: tabs),
      ),
      floatingActionButton: _buildFab(),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.staff),
          TabBarView(
            controller: _tab,
            children: [
              if (!isWorker)
                _StaffTab(
                  user: u,
                  canManage: canManage,
                  onPaySalary: _paySalary,
                  onSetSalary: _setSalary,
                ),
              _TasksTab(user: u),
              _LeaveTab(user: u),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    final u = AuthService.instance.currentUser;
    if (u == null) return const SizedBox.shrink();

    // Worker/Vet: Görevler sekmesinde FAB yok (görev atayamazlar). İzinler
    // sekmesinde "İzin Talep Et" butonu.
    if (u.isWorker) {
      if (_tab.index == 1) {
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddLeaveRequestScreen()));
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.event_busy, color: Colors.white),
          label: const Text('İzin Talep Et',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.primaryGreen,
        );
      }
      return const SizedBox.shrink();
    }

    // Vet: Personel(0) ve Görevler(1) sekmelerinde FAB yok. İzinler(2)'de izin talep.
    if (u.isVet) {
      if (_tab.index == 2) {
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddLeaveRequestScreen()));
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.event_busy, color: Colors.white),
          label: const Text('İzin Talep Et',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.primaryGreen,
        );
      }
      return const SizedBox.shrink();
    }

    // Partner (salt-okunur): hiçbir sekmede FAB yok
    if (!u.canManageStaff) return const SizedBox.shrink();

    // Owner/Assistant:
    // - Personel tab (0): FAB yok — kullanıcılar Ayarlar → Kullanıcı Yönetimi'nden eklenir
    // - Görevler tab (1): "Görev Ata"
    // - İzinler tab (2): FAB yok — yönetici cevap verir, kendisi talep oluşturmaz
    if (_tab.index != 1) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AddFarmTaskScreen()));
        if (mounted) setState(() {});
      },
      icon: const Icon(Icons.add_task, color: Colors.white),
      label: const Text('Görev Ata',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.primaryGreen,
    );
  }
}

// ─── PERSONEL TAB (Firestore members) ────────────────────

class _StaffTab extends StatelessWidget {
  final UserModel? user;
  final bool canManage;
  final Future<void> Function(FarmMember) onPaySalary;
  final Future<void> Function(FarmMember) onSetSalary;
  const _StaffTab({
    required this.user,
    required this.canManage,
    required this.onPaySalary,
    required this.onSetSalary,
  });

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null || u.activeFarmId == null) {
      return const Center(child: Text('Çiftlik seçili değil'));
    }
    return StreamBuilder<List<FarmMember>>(
      stream: FarmMemberService.instance.streamMembers(u.activeFarmId!),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }
        final all = snap.data ?? const <FarmMember>[];
        // Giriş yapan kullanıcı listede görünmesin — personel ekranı diğer üyeleri
        // yönetmek için; kendi bilgilerini Ayarlar → Profil'den düzenler.
        final others = all.where((m) => m.uid != u.uid).toList();
        if (others.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'Personel Yok',
            subtitle: 'Henüz çiftlikte başka kullanıcı yok.\nAyarlar → Kullanıcı Yönetimi\'nden ekleyebilirsiniz.',
          );
        }

        // Rol sırasına göre grupla: Ana Sahip → Yardımcı → Ortak → Vet → Personel
        int roleOrder(String role) {
          switch (role) {
            case AppConstants.roleOwner: return 0;
            case AppConstants.roleAssistant: return 1;
            case AppConstants.rolePartner: return 2;
            case AppConstants.roleVet: return 3;
            case AppConstants.roleWorker: return 4;
            default: return 5;
          }
        }
        final sorted = [...others]..sort((a, b) {
          final r = roleOrder(a.role).compareTo(roleOrder(b.role));
          if (r != 0) return r;
          return a.displayName.compareTo(b.displayName);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final m = sorted[i];
            return _MemberCard(
              member: m,
              canManage: canManage,
              currentUid: u.uid,
              onPaySalary: () => onPaySalary(m),
              onSetSalary: () => onSetSalary(m),
            );
          },
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FarmMember member;
  final bool canManage;
  final String currentUid;
  final VoidCallback onPaySalary;
  final VoidCallback onSetSalary;
  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.currentUid,
    required this.onPaySalary,
    required this.onSetSalary,
  });

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleOwner:     return AppColors.primaryGreen;
      case AppConstants.roleAssistant: return const Color(0xFF1976D2);
      case AppConstants.rolePartner:   return AppColors.gold;
      case AppConstants.roleVet:       return AppColors.errorRed;
      case AppConstants.roleWorker:    return AppColors.infoBlue;
      default: return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(member.role);
    final fmt = NumberFormat('#,##0', 'tr_TR');
    final dfmt = DateFormat('dd.MM.yyyy');
    final isSelf = member.uid == currentUid;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : (member.email.isNotEmpty ? member.email[0].toUpperCase() : '?');

    // Owner kartında eylem menüsü yok — ana sahip her zaman aktif ve maaş öde
    // akışı ana sahibi kapsamaz. Kendi kartında da eylem menüsü gerekmez.
    final showMenu = canManage && !member.isOwner && !isSelf;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(
          color: member.isActive ? color : AppColors.textGrey,
          width: 4,
        )),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(initial, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(
              member.displayName.isNotEmpty ? member.displayName : member.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Siz', style: TextStyle(
                fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.w700,
              )),
            ),
          if (!member.isActive) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textGrey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Pasif', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(member.roleLabel, style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700,
                )),
              ),
              if (member.monthlySalary != null)
                MaskedAmount(
                  text: '₺${fmt.format(member.monthlySalary!)} / ay',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
            ]),
          ),
          if (member.email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(member.email,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Katılım: ${dfmt.format(member.joinedAt)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ),
        ]),
        trailing: showMenu
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'pay') onPaySalary();
                  if (v == 'salary') onSetSalary();
                },
                itemBuilder: (_) => [
                  if (member.isActive)
                    const PopupMenuItem(value: 'pay',
                        child: Row(children: [
                          Icon(Icons.payments_outlined, color: AppColors.primaryGreen, size: 18),
                          SizedBox(width: 8),
                          Text('Maaş Öde'),
                        ])),
                  const PopupMenuItem(value: 'salary',
                      child: Row(children: [
                        Icon(Icons.attach_money, color: AppColors.infoBlue, size: 18),
                        SizedBox(width: 8),
                        Text('Maaş Ayarla'),
                      ])),
                ],
              )
            : null,
      ),
    );
  }
}

// ─── GÖREVLER TAB (Firestore) ────────────────────────────

class _TasksTab extends StatelessWidget {
  final UserModel? user;
  const _TasksTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null || u.activeFarmId == null) {
      return const Center(child: Text('Çiftlik seçili değil'));
    }
    final farmId = u.activeFarmId!;
    final stream = u.isWorker
        ? FarmTaskService.instance.streamForStaff(farmId: farmId, staffUid: u.uid)
        : FarmTaskService.instance.streamAllForFarm(farmId);

    return StreamBuilder<List<FarmTask>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }
        final tasks = snap.data ?? const <FarmTask>[];
        if (tasks.isEmpty) {
          return EmptyState(
            icon: Icons.task_alt,
            title: 'Görev Yok',
            subtitle: u.isWorker
                ? 'Size atanmış görev bulunmuyor.'
                : 'Henüz görev atanmamış.\nSağ alttaki butona basarak görev atayabilirsiniz.',
          );
        }

        final active = tasks.where((t) => t.isActive).toList();
        final overdue = active.where((t) => t.isOverdue).toList();
        final upcoming = active.where((t) => !t.isOverdue).toList();
        final done = tasks.where((t) => t.isCompleted || t.isCancelled).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            if (overdue.isNotEmpty) ...[
              _SectionHeader(title: 'Gecikmiş (${overdue.length})', color: AppColors.errorRed),
              ...overdue.map((t) => _FarmTaskCard(task: t, user: u)),
              const SizedBox(height: 8),
            ],
            if (upcoming.isNotEmpty) ...[
              _SectionHeader(title: 'Aktif (${upcoming.length})', color: AppColors.infoBlue),
              ...upcoming.map((t) => _FarmTaskCard(task: t, user: u)),
              const SizedBox(height: 8),
            ],
            if (done.isNotEmpty) ...[
              _SectionHeader(title: 'Tamamlanan (${done.length})', color: AppColors.primaryGreen),
              ...done.map((t) => _FarmTaskCard(task: t, user: u)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(children: [
        Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _FarmTaskCard extends StatelessWidget {
  final FarmTask task;
  final UserModel user;
  const _FarmTaskCard({required this.task, required this.user});

  Color _priorityColor(String p) {
    switch (p) {
      case AppConstants.taskPriorityHigh: return AppColors.errorRed;
      case AppConstants.taskPriorityNormal: return AppColors.infoBlue;
      default: return AppColors.primaryGreen;
    }
  }

  Future<void> _complete(BuildContext context) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Görevi Tamamla'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Tamamlama Notu (opsiyonel)',
              hintText: 'Nasıl yapıldı, karşılaşılan durum vb.',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Tamamla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await FarmTaskService.instance.updateStatus(
      farmId: task.farmId,
      taskId: task.id!,
      newStatus: AppConstants.taskStatusCompleted,
      completionNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: Text('"${task.title}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final backup = task;
      final err = await FarmTaskService.instance.delete(
          farmId: task.farmId, taskId: task.id!);
      if (!context.mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
        );
        return;
      }
      UndoSnackbar.show(
        context,
        message: '"${backup.title}" görevi silindi',
        onUndo: () async {
          // Firestore doc id kaybolur — aynı içerikle yeni doc oluştur
          await FarmTaskService.instance.create(FarmTask(
            farmId: backup.farmId,
            title: backup.title,
            description: backup.description,
            assignedToUid: backup.assignedToUid,
            assignedToName: backup.assignedToName,
            assignedByUid: backup.assignedByUid,
            assignedByName: backup.assignedByName,
            dueDate: backup.dueDate,
            priority: backup.priority,
            status: backup.status,
            completionNote: backup.completionNote,
            createdAt: backup.createdAt,
            completedAt: backup.completedAt,
          ));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);
    final fmt = DateFormat('dd.MM.yyyy');
    final completed = task.isCompleted || task.isCancelled;
    final canComplete = !completed && task.assignedToUid == user.uid;
    final canDelete = user.canManageStaff;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: completed
                ? AppColors.divider
                : task.isOverdue ? AppColors.errorRed : color,
            width: 3,
          ),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: canComplete
            ? GestureDetector(
                onTap: () => _complete(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: completed ? AppColors.primaryGreen : Colors.transparent,
                  border: Border.all(
                    color: completed ? AppColors.primaryGreen : AppColors.divider,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: completed
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? AppColors.textGrey : AppColors.textDark,
          ),
        ),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (task.description != null && task.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(task.description!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              _Chip(
                icon: Icons.person_outline,
                text: task.assignedToName,
                color: AppColors.infoBlue,
              ),
              if (task.dueDate != null)
                _Chip(
                  icon: Icons.calendar_today,
                  text: fmt.format(task.dueDate!),
                  color: task.isOverdue ? AppColors.errorRed : AppColors.textGrey,
                ),
              if (!completed)
                _Chip(
                  icon: Icons.flag_outlined,
                  text: task.priorityLabel,
                  color: color,
                ),
              if (task.isOverdue)
                const _Chip(
                  icon: Icons.warning_amber,
                  text: 'Gecikmiş',
                  color: AppColors.errorRed,
                ),
            ]),
          ),
          if (task.completionNote != null && task.completionNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📝 ${task.completionNote}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen)),
            ),
        ]),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 20),
                onPressed: () => _delete(context),
              )
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── İZİN TAB (Firestore) ────────────────────────────────

class _LeaveTab extends StatelessWidget {
  final UserModel? user;
  const _LeaveTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null || u.activeFarmId == null) {
      return const Center(child: Text('Çiftlik seçili değil'));
    }
    final farmId = u.activeFarmId!;
    final stream = (u.isWorker || u.isVet)
        ? LeaveRequestService.instance.streamForStaff(farmId: farmId, staffUid: u.uid)
        : LeaveRequestService.instance.streamAllForFarm(farmId);

    return StreamBuilder<List<LeaveRequest>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }
        final list = snap.data ?? const <LeaveRequest>[];
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy,
            title: 'İzin Talebi Yok',
            subtitle: (u.isWorker || u.isVet)
                ? 'Henüz izin talebiniz bulunmuyor.\nSağ alttaki butondan talep oluşturabilirsiniz.'
                : 'Henüz izin talebi bulunmuyor.',
          );
        }

        final pending = list.where((l) => l.isPending).toList();
        final responded = list.where((l) => !l.isPending).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            if (pending.isNotEmpty) ...[
              _SectionHeader(title: 'Bekleyen (${pending.length})', color: AppColors.gold),
              ...pending.map((l) => _LeaveCard(leave: l, user: u)),
              const SizedBox(height: 8),
            ],
            if (responded.isNotEmpty) ...[
              _SectionHeader(title: 'Geçmiş (${responded.length})', color: AppColors.textGrey),
              ...responded.map((l) => _LeaveCard(leave: l, user: u)),
            ],
          ],
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final UserModel user;
  const _LeaveCard({required this.leave, required this.user});

  Color _statusColor() {
    if (leave.isApproved) return AppColors.primaryGreen;
    if (leave.isRejected) return AppColors.errorRed;
    return AppColors.gold;
  }

  Future<void> _respond(BuildContext context, bool approve) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(approve ? 'İzin Onayla' : 'İzin Reddet'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${leave.staffName} — ${leave.reason}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: approve ? 'Onay notu (opsiyonel)' : 'Red gerekçesi (opsiyonel)',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.primaryGreen : AppColors.errorRed,
            ),
            child: Text(approve ? 'Onayla' : 'Reddet',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await LeaveRequestService.instance.respond(
      farmId: leave.farmId,
      requestId: leave.id!,
      approved: approve,
      respondedByUid: user.uid,
      respondedByName: user.displayName,
      responseNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? (approve ? 'İzin onaylandı' : 'İzin reddedildi')),
          backgroundColor: err != null ? AppColors.errorRed : AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İzin Talebini Sil'),
        content: const Text('Talep kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final backup = leave;
      final err = await LeaveRequestService.instance.delete(
        farmId: leave.farmId, requestId: leave.id!);
      if (!context.mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
        );
        return;
      }
      UndoSnackbar.show(
        context,
        message: '${backup.reason} izin talebi silindi',
        onUndo: () async {
          await LeaveRequestService.instance.create(LeaveRequest(
            farmId: backup.farmId,
            staffUid: backup.staffUid,
            staffName: backup.staffName,
            startDate: backup.startDate,
            endDate: backup.endDate,
            reason: backup.reason,
            notes: backup.notes,
            status: backup.status,
            respondedByUid: backup.respondedByUid,
            respondedByName: backup.respondedByName,
            responseNote: backup.responseNote,
            createdAt: backup.createdAt,
            respondedAt: backup.respondedAt,
          ));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final fmt = DateFormat('dd.MM.yyyy');
    final canRespond = user.canManageStaff && leave.isPending;
    final canDelete = user.canManageStaff ||
        (leave.staffUid == user.uid && leave.isPending);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                leave.staffName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                leave.statusLabel,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${leave.reason} · ${leave.dayCount} gün',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(leave.startDate)}  →  ${fmt.format(leave.endDate)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          if (leave.notes != null && leave.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('📝 ${leave.notes}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
          if (leave.responseNote != null && leave.responseNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${leave.respondedByName ?? ''} yanıtı:',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                ),
                Text(leave.responseNote!, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ],
          if (canRespond || canDelete) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (canRespond) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respond(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      side: const BorderSide(color: AppColors.errorRed),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respond(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('Onayla', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ] else if (canDelete) ...[
                TextButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                  label: const Text('Sil', style: TextStyle(color: AppColors.errorRed)),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─── GÖREV ATA (Firestore) ───────────────────────────────

class AddFarmTaskScreen extends StatefulWidget {
  const AddFarmTaskScreen({super.key});

  @override
  State<AddFarmTaskScreen> createState() => _AddFarmTaskScreenState();
}

class _AddFarmTaskScreenState extends State<AddFarmTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  UserModel? _assignedTo;
  String _priority = AppConstants.taskPriorityNormal;
  DateTime? _dueDate;
  bool _saving = false;
  bool _loadingMembers = true;
  List<UserModel> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final all = await AuthService.instance.getFarmUsers();
      // Atanabilir roller: worker, assistant (kendisi hariç). Owner yeteri kadar
      // yetkilidir zaten — kendi kendine görev atamaya ihtiyaç yok.
      final currentUid = AuthService.instance.currentUser?.uid;
      final list = all.where((u) {
        if (u.uid == currentUid) return false;
        if (!u.isActive) return false;
        return u.isWorker || u.isAssistant;
      }).toList();
      setState(() {
        _members = list;
        _loadingMembers = false;
      });
    } catch (_) {
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atanacak kişi seçin')),
      );
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;

    setState(() => _saving = true);
    final task = FarmTask(
      farmId: user.activeFarmId!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      assignedToUid: _assignedTo!.uid,
      assignedToName: _assignedTo!.displayName,
      assignedByUid: user.uid,
      assignedByName: user.displayName,
      dueDate: _dueDate,
      priority: _priority,
      status: AppConstants.taskStatusPending,
      createdAt: DateTime.now(),
    );
    final id = await FarmTaskService.instance.create(task);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görev oluşturulamadı'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Ata'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: _loadingMembers
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _FormCard(title: 'Görev Bilgileri', children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Görev Başlığı *',
                        prefixIcon: Icon(Icons.task_alt, color: AppColors.primaryGreen),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Başlık giriniz' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        prefixIcon: Icon(Icons.notes, color: AppColors.textGrey),
                      ),
                      maxLines: 3,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _FormCard(title: 'Öncelik', children: [
                    Row(children: [
                      AppConstants.taskPriorityLow,
                      AppConstants.taskPriorityNormal,
                      AppConstants.taskPriorityHigh,
                    ].map((p) {
                      final selected = _priority == p;
                      final color = p == AppConstants.taskPriorityHigh
                          ? AppColors.errorRed
                          : p == AppConstants.taskPriorityNormal
                              ? AppColors.infoBlue
                              : AppColors.primaryGreen;
                      final label = AppConstants.taskPriorityLabels[p] ?? p;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _priority = p),
                          child: Container(
                            margin: EdgeInsets.only(right: p != AppConstants.taskPriorityHigh ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? color : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selected ? color : Colors.grey.shade300),
                            ),
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: selected ? Colors.white : AppColors.textGrey,
                                )),
                          ),
                        ),
                      );
                    }).toList()),
                  ]),
                  const SizedBox(height: 16),
                  _FormCard(title: 'Atama & Tarih', children: [
                    if (_members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Atanabilir kullanıcı yok.\nÖnce Ayarlar → Kullanıcı Yönetimi\'nden personel/yardımcı ekleyin.',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<UserModel>(
        initialValue: _assignedTo,
                        decoration: const InputDecoration(
                          labelText: 'Atanan Kullanıcı *',
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryGreen),
                        ),
                        items: _members
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text('${u.displayName} · ${u.roleDisplay}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _assignedTo = v),
                        validator: (v) => v == null ? 'Atanacak kişiyi seçin' : null,
                      ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _dueDate == null
                                ? 'Son Tarih (isteğe bağlı)'
                                : DateFormat('dd.MM.yyyy').format(_dueDate!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate == null ? AppColors.textGrey : AppColors.textDark,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── YENİ İZİN TALEBİ ────────────────────────────────────

class AddLeaveRequestScreen extends StatefulWidget {
  const AddLeaveRequestScreen({super.key});

  @override
  State<AddLeaveRequestScreen> createState() => _AddLeaveRequestScreenState();
}

class _AddLeaveRequestScreenState extends State<AddLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  String _reason = AppConstants.leaveReasons.first;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _dayCount {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlangıç ve bitiş tarihi seçin')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş tarihi başlangıçtan önce olamaz')),
      );
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;

    setState(() => _saving = true);
    final req = LeaveRequest(
      farmId: user.activeFarmId!,
      staffUid: user.uid,
      staffName: user.displayName,
      startDate: _startDate!,
      endDate: _endDate!,
      reason: _reason,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: AppConstants.leaveStatusPending,
      createdAt: DateTime.now(),
    );
    final id = await LeaveRequestService.instance.create(req);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talep oluşturulamadı'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ??
        (isStart ? DateTime.now() : (_startDate ?? DateTime.now()));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('İzin Talep Et'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormCard(title: 'İzin Türü', children: [
              DropdownButtonFormField<String>(
        initialValue: _reason,
                decoration: const InputDecoration(
                  labelText: 'Gerekçe',
                  prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryGreen),
                ),
                items: AppConstants.leaveReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _reason = v!),
              ),
            ]),
            const SizedBox(height: 16),
            _FormCard(title: 'Tarih Aralığı', children: [
              GestureDetector(
                onTap: () => _pickDate(isStart: true),
                child: _DateField(
                  label: 'Başlangıç Tarihi *',
                  value: _startDate == null ? null : fmt.format(_startDate!),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _pickDate(isStart: false),
                child: _DateField(
                  label: 'Bitiş Tarihi *',
                  value: _endDate == null ? null : fmt.format(_endDate!),
                ),
              ),
              if (_dayCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_note, color: AppColors.primaryGreen, size: 18),
                    const SizedBox(width: 8),
                    Text('Toplam $_dayCount gün',
                        style: const TextStyle(
                            color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            _FormCard(title: 'Açıklama', children: [
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ek not (opsiyonel)',
                  prefixIcon: Icon(Icons.notes, color: AppColors.textGrey),
                ),
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  const _DateField({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 12),
        Text(
          value ?? label,
          style: TextStyle(
            fontSize: 14,
            color: value == null ? AppColors.textGrey : AppColors.textDark,
          ),
        ),
      ]),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}
