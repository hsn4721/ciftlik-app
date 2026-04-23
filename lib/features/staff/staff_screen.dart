import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/finance_model.dart';
import '../../data/repositories/staff_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/empty_state.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _repo = StaffRepository();
  final _financeRepo = FinanceRepository();
  List<StaffModel> _staff = [];
  List<TaskModel> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final staff = await _repo.getAllStaff();
      final tasks = await _repo.getAllTasks();
      setState(() {
        _staff = staff;
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteStaff(StaffModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text('${s.name} kaydı silinsin mi?'),
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
      await _repo.deleteStaff(s.id!);
      _load();
    }
  }

  Future<void> _paySalary(StaffModel s) async {
    final now = DateTime.now();
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final amountCtrl = TextEditingController(
        text: s.salary != null ? s.salary!.toStringAsFixed(2) : '');
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
          Text('Maaş Öde — ${s.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (s.salary != null) ...[
            const SizedBox(height: 4),
            Text('Kayıtlı maaş: ₺${fmt.format(s.salary!)} / ay',
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
      try {
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.expense,
          category: AppConstants.expenseLabor,
          amount: amount,
          date: today,
          description: '${s.name} maaş ödemesi — ${s.role}',
          notes: note,
          createdAt: now.toIso8601String(),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('₺${fmt.format(amount)} maaş ödemesi finansa kaydedildi'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  Future<void> _deleteTask(TaskModel t) async {
    await _repo.deleteTask(t.id!);
    _load();
  }

  Future<void> _toggleTask(TaskModel t) async {
    await _repo.toggleTask(t.id!, !t.isCompleted);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _tasks.where((t) => !t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel & Görevler'),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('$pendingCount Bekleyen', style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.errorRed,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Personel'), Tab(text: 'Görevler')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('Ne eklemek istersiniz?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person_add_outlined, color: AppColors.primaryGreen)),
                    title: const Text('Personel Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Yeni çalışan kaydı oluştur', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                    onTap: () => Navigator.pop(context, 'staff'),
                  ),
                  ListTile(
                    leading: Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.infoBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.task_alt, color: AppColors.infoBlue)),
                    title: const Text('Görev Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Personele görev ata', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                    onTap: () => Navigator.pop(context, 'task'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
          if (!mounted) return;
          if (result == 'staff') {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStaffScreen()));
          } else if (result == 'task') {
            final activeStaff = await _repo.getActiveStaff();
            if (!mounted) return;
            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskScreen(staff: activeStaff)));
          }
          _load();
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.staff),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _StaffTab(staff: _staff, onDelete: _deleteStaff, onPaySalary: _paySalary, onRefresh: _load),
                      _TasksTab(tasks: _tasks, onToggle: _toggleTask, onDelete: _deleteTask, onRefresh: _load),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── PERSONEL TAB ────────────────────────────────────────

class _StaffTab extends StatelessWidget {
  final List<StaffModel> staff;
  final Function(StaffModel) onDelete;
  final Function(StaffModel) onPaySalary;
  final VoidCallback onRefresh;
  const _StaffTab({required this.staff, required this.onDelete, required this.onPaySalary, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Personel Yok',
        subtitle: 'Henüz personel kaydı eklenmemiş.\nSağ alttaki butona basarak ekleyebilirsiniz.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: staff.length,
        itemBuilder: (_, i) {
          final s = staff[i];
          return _StaffCard(staff: s, onDelete: () => onDelete(s), onPaySalary: () => onPaySalary(s));
        },
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffModel staff;
  final VoidCallback onDelete;
  final VoidCallback onPaySalary;
  const _StaffCard({required this.staff, required this.onDelete, required this.onPaySalary});

  Color _roleColor(String role) {
    switch (role) {
      case 'Veteriner': return AppColors.errorRed;
      case 'Muhasebe': return AppColors.gold;
      case 'Ustabaşı': return const Color(0xFF6A1B9A);
      default: return AppColors.infoBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(staff.role);
    final fmt = NumberFormat('#,##0', 'tr_TR');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: staff.isActive ? color : AppColors.textGrey, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(staff.name[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ),
        title: Row(children: [
          Expanded(child: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (!staff.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.textGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Pasif', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(staff.role, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          if (staff.salary != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('₺${fmt.format(staff.salary!)} / ay',
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ),
          if (staff.phone != null)
            Text(staff.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') onDelete();
            if (v == 'salary') onPaySalary();
          },
          itemBuilder: (_) => [
            if (staff.salary != null && staff.isActive)
              const PopupMenuItem(value: 'salary',
                  child: Row(children: [
                    Icon(Icons.payments_outlined, color: AppColors.primaryGreen, size: 18),
                    SizedBox(width: 8),
                    Text('Maaş Öde'),
                  ])),
            const PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Sil'),
                ])),
          ],
        ),
      ),
    );
  }
}

// ─── GÖREVLER TAB ────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final List<TaskModel> tasks;
  final Function(TaskModel) onToggle;
  final Function(TaskModel) onDelete;
  final VoidCallback onRefresh;
  const _TasksTab({required this.tasks, required this.onToggle, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'Görev Yok',
        subtitle: 'Henüz görev eklenmemiş.\nSağ alttaki butona basarak ekleyebilirsiniz.',
      );
    }
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          if (pending.isNotEmpty) ...[
            _SectionHeader(title: 'Bekleyen (${pending.length})', color: AppColors.errorRed),
            ...pending.map((t) => _TaskCard(task: t, onToggle: () => onToggle(t), onDelete: () => onDelete(t))),
            const SizedBox(height: 8),
          ],
          if (done.isNotEmpty) ...[
            _SectionHeader(title: 'Tamamlanan (${done.length})', color: AppColors.primaryGreen),
            ...done.map((t) => _TaskCard(task: t, onToggle: () => onToggle(t), onDelete: () => onDelete(t))),
          ],
        ],
      ),
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

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TaskCard({required this.task, required this.onToggle, required this.onDelete});

  Color _priorityColor(String p) {
    switch (p) {
      case 'Acil': return AppColors.errorRed;
      case 'Yüksek': return AppColors.gold;
      default: return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: task.isCompleted ? AppColors.divider : color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: task.isCompleted ? AppColors.primaryGreen : Colors.transparent,
              border: Border.all(color: task.isCompleted ? AppColors.primaryGreen : AppColors.divider, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: task.isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),
        title: Text(task.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? AppColors.textGrey : AppColors.textDark,
            )),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (task.assignedToName != null)
            Text('Atanan: ${task.assignedToName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          if (task.dueDate != null)
            Text('Tarih: ${task.dueDate}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          if (!task.isCompleted)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(task.priority, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
        ]),
        trailing: GestureDetector(
          onTap: onDelete,
          child: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 18),
        ),
      ),
    );
  }
}

// ─── PERSONEL EKLE ───────────────────────────────────────

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = StaffRepository();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _role = AppConstants.staffRoles.first;
  DateTime? _startDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _salaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = StaffModel(
      name: _nameCtrl.text.trim(),
      role: _role,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      salary: _salaryCtrl.text.trim().isEmpty ? null : double.tryParse(_salaryCtrl.text.replaceAll(',', '.')),
      startDate: _startDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insertStaff(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Ekle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormCard(title: 'Kişisel Bilgiler', children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad *',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryGreen),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Ad soyad giriniz' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Görev / Rol',
                  prefixIcon: Icon(Icons.work_outline, color: AppColors.primaryGreen),
                ),
                items: AppConstants.staffRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryGreen),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _FormCard(title: 'İş Bilgileri', children: [
              TextFormField(
                controller: _salaryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Aylık Maaş (₺)',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _startDate = picked);
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
                      _startDate == null
                          ? 'İşe Başlama Tarihi'
                          : DateFormat('dd.MM.yyyy').format(_startDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _startDate == null ? AppColors.textGrey : AppColors.textDark,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notlar',
                  prefixIcon: Icon(Icons.notes, color: AppColors.textGrey),
                ),
                maxLines: 2,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── GÖREV EKLE ──────────────────────────────────────────

class AddTaskScreen extends StatefulWidget {
  final List<StaffModel> staff;
  const AddTaskScreen({super.key, required this.staff});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = StaffRepository();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  StaffModel? _assignedTo;
  String _priority = 'Normal';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = TaskModel(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      assignedToId: _assignedTo?.id,
      dueDate: _dueDate?.toIso8601String().split('T').first,
      priority: _priority,
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insertTask(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Ekle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
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
              Row(children: ['Normal', 'Yüksek', 'Acil'].map((p) {
                final selected = _priority == p;
                final color = p == 'Acil' ? AppColors.errorRed : p == 'Yüksek' ? AppColors.gold : AppColors.primaryGreen;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      margin: EdgeInsets.only(right: p != 'Acil' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? color : Colors.grey.shade300),
                      ),
                      child: Text(p,
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
              if (widget.staff.isNotEmpty)
                DropdownButtonFormField<StaffModel>(
                  value: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'Atanan Personel',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryGreen),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Atanmadı')),
                    ...widget.staff.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _assignedTo = v),
                )
              else
                const Text('Önce personel ekleyin', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
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
