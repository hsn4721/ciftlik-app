import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/equipment_model.dart';
import '../../data/repositories/equipment_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/undo_snackbar.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _repo = EquipmentRepository();
  List<EquipmentModel> _equipment = [];
  bool _loading = true;
  String _filterStatus = 'Tümü';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getAll();
      setState(() {
        _equipment = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[EquipmentScreen._load] $e\n$st');
      setState(() => _loading = false);
    }
  }

  List<EquipmentModel> get _filtered {
    if (_filterStatus == 'Tümü') return _equipment;
    return _equipment.where((e) => e.status == _filterStatus).toList();
  }

  Future<void> _delete(EquipmentModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ekipman Sil'),
        content: Text('${e.name} ekipmanı silinsin mi?'),
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
      final backup = e;
      await _repo.delete(e.id!);
      _load();
      if (mounted) {
        UndoSnackbar.show(
          context,
          message: '${backup.name} silindi',
          onUndo: () async {
            await _repo.insert(backup);
            _load();
          },
        );
      }
    }
  }

  Future<void> _updateStatus(EquipmentModel e, String newStatus) async {
    await _repo.update(e.copyWith(status: newStatus));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceDue = _equipment.where((e) => e.isMaintenanceDue).length;
    final broken = _equipment.where((e) => e.status == AppConstants.equipmentBroken).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekipman Yönetimi'),
        actions: [
          if (broken > 0 || maintenanceDue > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(
                  broken > 0 ? '$broken Arızalı' : '$maintenanceDue Bakım Yakın',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: broken > 0 ? AppColors.errorRed : AppColors.gold,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      floatingActionButton: Builder(builder: (_) {
        final u = AuthService.instance.currentUser;
        if (u != null && !u.canManageEquipment) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEquipmentScreen()));
            _load();
          },
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Ekipman Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        );
      }),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.equipment),
          Column(
            children: [
              _StatusFilterBar(selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _EquipmentList(
                        equipment: _filtered,
                        onDelete: _delete,
                        onStatusChange: _updateStatus,
                        onRefresh: _load,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String selected;
  final Function(String) onSelected;

  const _StatusFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = ['Tümü', AppConstants.equipmentActive, AppConstants.equipmentMaintenance, AppConstants.equipmentBroken];
    return Container(
      height: 48,
      color: AppColors.primaryGreen.withValues(alpha: 0.06),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: options.map((opt) {
          final isSelected = selected == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(opt),
              child: Chip(
                label: Text(opt, style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                )),
                backgroundColor: isSelected ? AppColors.primaryGreen : Colors.white,
                side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EquipmentList extends StatelessWidget {
  final List<EquipmentModel> equipment;
  final Function(EquipmentModel) onDelete;
  final Function(EquipmentModel, String) onStatusChange;
  final Future<void> Function() onRefresh;

  const _EquipmentList({
    required this.equipment,
    required this.onDelete,
    required this.onStatusChange,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (equipment.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            EmptyState(
              icon: Icons.build_outlined,
              title: 'Ekipman Yok',
              subtitle: 'Henüz ekipman kaydı eklenmemiş.\nSağ alttaki butona basarak ekleyebilirsiniz.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: equipment.length,
        itemBuilder: (_, i) {
          final e = equipment[i];
          return _EquipmentCard(equipment: e, onDelete: onDelete, onStatusChange: onStatusChange);
        },
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final EquipmentModel equipment;
  final Function(EquipmentModel) onDelete;
  final Function(EquipmentModel, String) onStatusChange;

  const _EquipmentCard({required this.equipment, required this.onDelete, required this.onStatusChange});

  Color _statusColor(String status) {
    switch (status) {
      case 'Çalışıyor': return AppColors.primaryGreen;
      case 'Bakımda': return AppColors.gold;
      case 'Arızalı': return AppColors.errorRed;
      default: return AppColors.textGrey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Sağım Makinesi': return Icons.water_drop;
      case 'Traktör': return Icons.agriculture;
      case 'Sulama Sistemi': return Icons.waves;
      case 'Aydınlatma': return Icons.light;
      case 'Soğutma': return Icons.ac_unit;
      default: return Icons.build;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = equipment;
    final statusColor = _statusColor(e.status);
    final fmt = NumberFormat('#,##0.00', 'tr_TR');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Icon(_categoryIcon(e.category), color: statusColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(e.category, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(e.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  onDelete(e);
                } else {
                  onStatusChange(e, v);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: AppConstants.equipmentActive,
                  child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 8), Text('Çalışıyor')])),
                const PopupMenuItem(value: AppConstants.equipmentMaintenance,
                  child: Row(children: [Icon(Icons.build_circle, color: Colors.amber, size: 16), SizedBox(width: 8), Text('Bakımda')])),
                const PopupMenuItem(value: AppConstants.equipmentBroken,
                  child: Row(children: [Icon(Icons.cancel, color: Colors.red, size: 16), SizedBox(width: 8), Text('Arızalı')])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete',
                  child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 16), SizedBox(width: 8), Text('Sil')])),
              ],
            ),
          ]),
          if (e.brand != null || e.model != null) ...[
            const SizedBox(height: 6),
            Text('${e.brand ?? ''} ${e.model ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
          if (e.purchasePrice != null || e.nextMaintenanceDate != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              if (e.purchasePrice != null)
                Text('Alış: ₺${fmt.format(e.purchasePrice!)}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (e.purchasePrice != null && e.nextMaintenanceDate != null)
                const Text(' • ', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (e.nextMaintenanceDate != null)
                Text(
                  'Bakım: ${DateFormat('dd.MM.yyyy').format(e.nextMaintenanceDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: e.isMaintenanceDue ? AppColors.gold : AppColors.textGrey,
                    fontWeight: e.isMaintenanceDue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD EQUIPMENT SCREEN
// ─────────────────────────────────────────────

class AddEquipmentScreen extends StatefulWidget {
  const AddEquipmentScreen({super.key});

  @override
  State<AddEquipmentScreen> createState() => _AddEquipmentScreenState();
}

class _AddEquipmentScreenState extends State<AddEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EquipmentRepository();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = AppConstants.equipmentCategories.first;
  String _status = AppConstants.equipmentActive;
  DateTime? _purchaseDate;
  DateTime? _nextMaintenance;
  bool _saving = false;

  Future<void> _pickPurchaseDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _purchaseDate = d);
  }

  Future<void> _pickMaintenanceDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _nextMaintenance ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _nextMaintenance = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = EquipmentModel(
      name: _nameCtrl.text.trim(),
      category: _category,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      serialNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
      purchaseDate: _purchaseDate,
      purchasePrice: _priceCtrl.text.isEmpty ? null : double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
      status: _status,
      nextMaintenanceDate: _nextMaintenance,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insert(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekipman Ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Ekipman Adı *'),
                    validator: (v) => v == null || v.isEmpty ? 'Ekipman adı giriniz' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
        initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: AppConstants.equipmentCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
        initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: [AppConstants.equipmentActive, AppConstants.equipmentMaintenance, AppConstants.equipmentBroken]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandCtrl,
                    decoration: const InputDecoration(labelText: 'Marka'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serialCtrl,
                    decoration: const InputDecoration(labelText: 'Seri No (İsteğe Bağlı)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(labelText: 'Alış Fiyatı (₺)', prefixText: '₺ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickPurchaseDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Alış Tarihi',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _purchaseDate != null
                            ? DateFormat('dd MMMM yyyy', 'tr_TR').format(_purchaseDate!)
                            : 'Tarih seçin',
                        style: TextStyle(color: _purchaseDate == null ? AppColors.textGrey : AppColors.textDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickMaintenanceDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Sonraki Bakım Tarihi',
                        suffixIcon: Icon(Icons.build, size: 18),
                      ),
                      child: Text(
                        _nextMaintenance != null
                            ? DateFormat('dd MMMM yyyy', 'tr_TR').format(_nextMaintenance!)
                            : 'Tarih seçin',
                        style: TextStyle(color: _nextMaintenance == null ? AppColors.textGrey : AppColors.textDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notlar'),
                    maxLines: 2,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Ekipman Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
