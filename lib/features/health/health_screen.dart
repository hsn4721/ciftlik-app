import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/health_model.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/models/animal_model.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/undo_snackbar.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = HealthRepository();
  List<HealthModel> _healthRecords = [];
  List<VaccineModel> _vaccines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final health = await _repo.getAllHealth();
      final vaccines = await _repo.getAllVaccines();
      setState(() { _healthRecords = health; _vaccines = vaccines; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sağlık kayıtları yüklenemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sağlık & Aşı'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Sağlık Kayıtları'), Tab(text: 'Aşı Takvimi')],
        ),
      ),
      floatingActionButton: Builder(builder: (_) {
        final u = AuthService.instance.currentUser;
        if (u != null && !u.canManageHealth) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () async {
            if (_tabController.index == 0) {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHealthScreen()));
              if (r == true) _load();
            } else {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVaccineScreen()));
              if (r == true) _load();
            }
          },
          backgroundColor: AppColors.errorRed,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            _tabController.index == 0 ? 'Kayıt Ekle' : 'Aşı Ekle',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        );
      }),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.health),
          _isLoading
              ? const SkeletonList(itemCount: 6, itemHeight: 80)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _HealthTab(records: _healthRecords, onRefresh: _load),
                    _VaccineTab(vaccines: _vaccines, onRefresh: _load),
                  ],
                ),
        ],
      ),
    );
  }
}

class _HealthTab extends StatelessWidget {
  final List<HealthModel> records;
  final VoidCallback onRefresh;
  const _HealthTab({required this.records, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_outline,
        title: 'Sağlık kaydı bulunmuyor',
        subtitle: 'Aşağıdaki butona basarak kayıt ekleyebilirsiniz',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        itemBuilder: (_, i) => _HealthTile(record: records[i], onDelete: onRefresh),
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final HealthModel record;
  final VoidCallback onDelete;
  const _HealthTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.errorRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.favorite, color: AppColors.errorRed, size: 20),
            ),
            title: Text(record.animalName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text('${record.type} • ${record.date}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            trailing: Builder(builder: (_) {
              final u = AuthService.instance.currentUser;
              final canEdit = u?.canManageHealth ?? true;
              if (!canEdit) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen, size: 18),
                    tooltip: 'Düzenle',
                    onPressed: () async {
                      final r = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddHealthScreen(initial: record)),
                      );
                      if (r == true) onDelete();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 18),
                    tooltip: 'Sil',
                    onPressed: () async {
                      final backup = record;
                      await HealthRepository().deleteHealth(record.id!);
                      onDelete();
                      if (context.mounted) {
                        UndoSnackbar.show(
                          context,
                          message: '${backup.animalName} — ${backup.type} silindi',
                          onUndo: () async {
                            await HealthRepository().insertHealth(backup);
                            onDelete();
                          },
                        );
                      }
                    },
                  ),
                ],
              );
            }),
          ),
          if (record.diagnosis != null || record.medicine != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  if (record.diagnosis != null)
                    _DetailRow(label: 'Teşhis', value: record.diagnosis!),
                  if (record.treatment != null)
                    _DetailRow(label: 'Tedavi', value: record.treatment!),
                  if (record.medicine != null)
                    _DetailRow(label: 'İlaç', value: '${record.medicine!}${record.dose != null ? ' (${record.dose})' : ''}'),
                  if (record.milkWithdrawal > 0)
                    _DetailRow(label: 'Süt Yasağı', value: '${record.milkWithdrawal} gün', isWarning: true),
                  if (record.vetName != null)
                    _DetailRow(label: 'Veteriner', value: record.vetName!),
                  if (record.cost != null)
                    _DetailRow(label: 'Ücret', value: '₺${record.cost!.toStringAsFixed(2)}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;
  const _DetailRow({required this.label, required this.value, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isWarning ? AppColors.errorRed : AppColors.textDark))),
        ],
      ),
    );
  }
}

class _VaccineTab extends StatelessWidget {
  final List<VaccineModel> vaccines;
  final VoidCallback onRefresh;
  const _VaccineTab({required this.vaccines, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (vaccines.isEmpty) {
      return const EmptyState(
        icon: Icons.vaccines,
        title: 'Aşı kaydı bulunmuyor',
        subtitle: 'Aşağıdaki butona basarak aşı kaydı ekleyebilirsiniz',
      );
    }

    final overdue = vaccines.where((v) => v.isOverdue).toList();
    final upcoming = vaccines.where((v) => !v.isOverdue && (v.daysUntilNext ?? 999) <= 30).toList();
    final rest = vaccines.where((v) => !v.isOverdue && (v.daysUntilNext ?? 999) > 30).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty) ...[
            _SectionHeader(title: 'Gecikmiş Aşılar', color: AppColors.errorRed),
            ...overdue.map((v) => _VaccineTile(vaccine: v, onDelete: onRefresh)),
          ],
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(title: 'Yaklaşan (30 gün)', color: AppColors.gold),
            ...upcoming.map((v) => _VaccineTile(vaccine: v, onDelete: onRefresh)),
          ],
          if (rest.isNotEmpty) ...[
            _SectionHeader(title: 'Tüm Kayıtlar', color: AppColors.primaryGreen),
            ...rest.map((v) => _VaccineTile(vaccine: v, onDelete: onRefresh)),
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
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _VaccineTile extends StatelessWidget {
  final VaccineModel vaccine;
  final VoidCallback onDelete;
  const _VaccineTile({required this.vaccine, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = vaccine.isOverdue ? AppColors.errorRed : vaccine.daysUntilNext != null && vaccine.daysUntilNext! <= 30 ? AppColors.gold : AppColors.primaryGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.vaccines, color: color, size: 20),
        ),
        title: Text(vaccine.vaccineName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vaccine.isHerdWide ? 'Tüm Sürü' : (vaccine.animalName ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            if (vaccine.nextVaccineDate != null)
              Text(
                vaccine.isOverdue ? 'GECİKMİŞ — ${vaccine.nextVaccineDate}' : 'Sonraki: ${vaccine.nextVaccineDate}',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: Builder(builder: (_) {
          final u = AuthService.instance.currentUser;
          final canEdit = u?.canManageHealth ?? true;
          if (!canEdit) return const SizedBox.shrink();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen, size: 18),
                tooltip: 'Düzenle',
                onPressed: () async {
                  final r = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddVaccineScreen(initial: vaccine)),
                  );
                  if (r == true) onDelete();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 18),
                tooltip: 'Sil',
                onPressed: () async {
                  final backup = vaccine;
                  await HealthRepository().deleteVaccine(vaccine.id!);
                  onDelete();
                  if (context.mounted) {
                    UndoSnackbar.show(
                      context,
                      message: '${backup.animalName} — ${backup.vaccineName} aşısı silindi',
                      onUndo: () async {
                        await HealthRepository().insertVaccine(backup);
                        onDelete();
                      },
                    );
                  }
                },
              ),
            ],
          );
        }),
      ),
    );
  }
}

class AddHealthScreen extends StatefulWidget {
  final HealthModel? initial; // null=yeni kayıt, dolu=düzenleme
  const AddHealthScreen({super.key, this.initial});

  @override
  State<AddHealthScreen> createState() => _AddHealthScreenState();
}

class _AddHealthScreenState extends State<AddHealthScreen> {
  final _repo = HealthRepository();
  final _animalRepo = AnimalRepository();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _medicineController = TextEditingController();
  final _doseController = TextEditingController();
  final _vetController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _withdrawalController = TextEditingController();

  List<AnimalModel> _animals = [];
  AnimalModel? _selectedAnimal;
  String _type = 'Hastalık';
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  final List<String> _types = [
    'Hastalık',
    'Yaralanma',
    'Mastitis',
    'Topallık',
    'Gebelik',
    'Gebelik Kontrolü',
    'Doğum',
    'Doğum Komplikasyonu',
    'Diğer',
  ];

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _diagnosisController.text = init.diagnosis ?? '';
      _treatmentController.text = init.treatment ?? '';
      _medicineController.text = init.medicine ?? '';
      _doseController.text = init.dose ?? '';
      _vetController.text = init.vetName ?? '';
      _costController.text = init.cost?.toString() ?? '';
      _notesController.text = init.notes ?? '';
      _withdrawalController.text = init.milkWithdrawal > 0 ? init.milkWithdrawal.toString() : '';
      if (_types.contains(init.type)) _type = init.type;
      _date = DateTime.tryParse(init.date) ?? DateTime.now();
    }
    _animalRepo.getAll().then((a) {
      if (!mounted) return;
      setState(() {
        _animals = a;
        if (init != null) {
          _selectedAnimal = a.where((x) => x.id == init.animalId).firstOrNull;
        }
      });
    });
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _medicineController.dispose();
    _doseController.dispose();
    _vetController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _withdrawalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedAnimal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hayvan seçin')));
      return;
    }
    setState(() => _isSaving = true);
    final withdrawal = int.tryParse(_withdrawalController.text) ?? 0;
    final init = widget.initial;
    final createdAt = init?.createdAt ?? DateTime.now().toIso8601String();
    final model = HealthModel(
      id: init?.id,
      animalId: _selectedAnimal!.id!,
      animalEarTag: _selectedAnimal!.earTag,
      animalName: _selectedAnimal!.name ?? _selectedAnimal!.earTag,
      date: _date.toIso8601String().split('T').first,
      type: _type,
      diagnosis: _diagnosisController.text.isEmpty ? null : _diagnosisController.text,
      treatment: _treatmentController.text.isEmpty ? null : _treatmentController.text,
      medicine: _medicineController.text.isEmpty ? null : _medicineController.text,
      dose: _doseController.text.isEmpty ? null : _doseController.text,
      milkWithdrawal: withdrawal,
      milkWithdrawalEnd: withdrawal > 0 ? _date.add(Duration(days: withdrawal)).toIso8601String().split('T').first : null,
      vetName: _vetController.text.isEmpty ? null : _vetController.text,
      cost: double.tryParse(_costController.text.replaceAll(',', '.')),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: createdAt,
    );
    try {
      if (_isEditing) {
        await _repo.updateHealth(model);
      } else {
        await _repo.insertHealth(model);
      }
      // Gebelik veya gebelik kontrolü kaydı → hayvanın durumu "Gebe" olarak işaretlensin
      if (!_isEditing &&
          (_type == 'Gebelik' || _type == 'Gebelik Kontrolü') &&
          _selectedAnimal != null) {
        final updated = _selectedAnimal!.copyWith(status: AppConstants.animalPregnant);
        await _animalRepo.update(updated);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Sağlık Kaydı Düzenle' : 'Sağlık Kaydı Ekle'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FormCard(title: 'Temel Bilgiler', children: [
            DropdownButtonFormField<AnimalModel>(
        initialValue: _selectedAnimal,
              hint: const Text('Hayvan seçin'),
              decoration: const InputDecoration(labelText: 'Hayvan *', prefixIcon: Icon(Icons.pets, color: AppColors.primaryGreen, size: 20)),
              items: _animals.map((a) => DropdownMenuItem(value: a, child: Text('${a.name ?? a.earTag} (${a.earTag})'))).toList(),
              onChanged: (v) => setState(() => _selectedAnimal = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
        initialValue: _type,
              decoration: const InputDecoration(labelText: 'Kayıt Türü', prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryGreen, size: 20)),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)), child: child!));
                if (p != null) setState(() => _date = p);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                  const SizedBox(width: 12),
                  Text('${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _FormCard(title: 'Tanı & Tedavi', children: [
            _field(_diagnosisController, 'Teşhis', Icons.search),
            const SizedBox(height: 12),
            _field(_treatmentController, 'Tedavi', Icons.medical_services_outlined),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_medicineController, 'İlaç', Icons.medication_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _field(_doseController, 'Doz', Icons.science_outlined)),
            ]),
            const SizedBox(height: 12),
            _field(_withdrawalController, 'Süt Yasağı (gün)', Icons.block, type: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          _FormCard(title: 'Veteriner & Maliyet', children: [
            _field(_vetController, 'Veteriner Adı', Icons.person_outlined),
            const SizedBox(height: 12),
            _field(_costController, 'Toplam Ücret (₺)', Icons.attach_money, type: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          _FormCard(title: 'Notlar', children: [
            _field(_notesController, 'Ek notlar', Icons.notes, maxLines: 3),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? type, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20)),
    );
  }
}

class AddVaccineScreen extends StatefulWidget {
  final VaccineModel? initial; // null=yeni kayıt, dolu=düzenleme
  const AddVaccineScreen({super.key, this.initial});

  @override
  State<AddVaccineScreen> createState() => _AddVaccineScreenState();
}

class _AddVaccineScreenState extends State<AddVaccineScreen> {
  final _repo = HealthRepository();
  final _animalRepo = AnimalRepository();
  final _doseController = TextEditingController();
  final _vetController = TextEditingController();
  final _costController = TextEditingController();
  final _batchController = TextEditingController();
  final _notesController = TextEditingController();

  List<AnimalModel> _animals = [];
  AnimalModel? _selectedAnimal;
  String _vaccineName = AppConstants.allVaccines.first;
  bool _isHerdWide = false;
  DateTime _vaccineDate = DateTime.now();
  DateTime? _nextDate;
  bool _isSaving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    // Düzenleme modundaysa mevcut kaydın alanlarını doldur
    final init = widget.initial;
    if (init != null) {
      _doseController.text = init.dose ?? '';
      _vetController.text = init.vetName ?? '';
      _costController.text = init.cost?.toString() ?? '';
      _batchController.text = init.batchNumber ?? '';
      _notesController.text = init.notes ?? '';
      // Dropdown değeri listede varsa kullan, yoksa ilkine düşer
      if (AppConstants.allVaccines.contains(init.vaccineName)) {
        _vaccineName = init.vaccineName;
      }
      _isHerdWide = init.isHerdWide;
      _vaccineDate = DateTime.tryParse(init.vaccineDate) ?? DateTime.now();
      _nextDate = init.nextVaccineDate != null ? DateTime.tryParse(init.nextVaccineDate!) : null;
    }
    _animalRepo.getAll().then((a) {
      if (!mounted) return;
      setState(() {
        _animals = a;
        // Hayvan seçimini düzenleme modunda eşleştir
        if (init != null && !init.isHerdWide && init.animalId != null) {
          _selectedAnimal = a.where((x) => x.id == init.animalId).firstOrNull;
        }
      });
    });
  }

  @override
  void dispose() {
    _doseController.dispose();
    _vetController.dispose();
    _costController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isHerdWide && _selectedAnimal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hayvan seçin veya "Tüm Sürü" seçeneğini işaretleyin')));
      return;
    }
    setState(() => _isSaving = true);
    final init = widget.initial;
    final createdAt = init?.createdAt ?? DateTime.now().toIso8601String();
    final model = VaccineModel(
      id: init?.id,
      animalId: _isHerdWide ? null : _selectedAnimal?.id,
      animalEarTag: _isHerdWide ? null : _selectedAnimal?.earTag,
      animalName: _isHerdWide ? null : _selectedAnimal?.name,
      isHerdWide: _isHerdWide,
      vaccineName: _vaccineName,
      vaccineDate: _vaccineDate.toIso8601String().split('T').first,
      nextVaccineDate: _nextDate?.toIso8601String().split('T').first,
      dose: _doseController.text.isEmpty ? null : _doseController.text,
      vetName: _vetController.text.isEmpty ? null : _vetController.text,
      cost: double.tryParse(_costController.text.replaceAll(',', '.')),
      batchNumber: _batchController.text.isEmpty ? null : _batchController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: createdAt,
    );
    try {
      if (_isEditing) {
        await _repo.updateVaccine(model);
      } else {
        await _repo.insertVaccine(model);
      }
      if (_nextDate != null && !_isHerdWide && _selectedAnimal != null) {
        await NotificationService.instance.scheduleVaccineReminder(
          id: createdAt.hashCode.abs(),
          animalName: _selectedAnimal!.name ?? _selectedAnimal!.earTag,
          vaccineName: _vaccineName,
          dueDate: _nextDate!,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aşı kaydedilemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Aşı Kaydı Düzenle' : 'Aşı Kaydı Ekle'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FormCard(title: 'Aşı Bilgileri', children: [
            DropdownButtonFormField<String>(
        initialValue: _vaccineName,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Aşı Adı',
                prefixIcon: Icon(Icons.vaccines, color: AppColors.primaryGreen, size: 20),
              ),
              items: _buildVaccineDropdownItems(),
              onChanged: (v) {
                if (v != null) setState(() => _vaccineName = v);
              },
            ),
            // Seçili aşı için tavsiye / takvim bilgisi
            if (AppConstants.vaccineSchedule[_vaccineName] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        AppConstants.vaccineCategory[_vaccineName] ?? '',
                        style: const TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConstants.vaccineSchedule[_vaccineName]!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.3),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
          value: _isHerdWide,
          activeThumbColor: AppColors.primaryGreen,
              onChanged: (v) => setState(() => _isHerdWide = v),
              title: const Text('Tüm Sürüye Uygulandı', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isHerdWide) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<AnimalModel>(
        initialValue: _selectedAnimal,
                hint: const Text('Hayvan seçin'),
                decoration: const InputDecoration(labelText: 'Hayvan', prefixIcon: Icon(Icons.pets, color: AppColors.primaryGreen, size: 20)),
                items: _animals.map((a) => DropdownMenuItem(value: a, child: Text('${a.name ?? a.earTag} (${a.earTag})'))).toList(),
                onChanged: (v) => setState(() => _selectedAnimal = v),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          _FormCard(title: 'Tarihler', children: [
            _DateTile(label: 'Aşı Tarihi', date: _vaccineDate, onTap: () async {
              final p = await _pickDate(_vaccineDate);
              if (p != null) setState(() => _vaccineDate = p);
            }),
            const SizedBox(height: 12),
            _DateTile(label: 'Sonraki Aşı Tarihi (isteğe bağlı)', date: _nextDate, onTap: () async {
              final p = await _pickDate(_nextDate ?? DateTime.now().add(const Duration(days: 180)));
              if (p != null) setState(() => _nextDate = p);
            }),
          ]),
          const SizedBox(height: 16),
          _FormCard(title: 'Detaylar', children: [
            TextFormField(controller: _doseController, decoration: const InputDecoration(labelText: 'Doz', prefixIcon: Icon(Icons.science_outlined, color: AppColors.primaryGreen, size: 20))),
            const SizedBox(height: 12),
            TextFormField(controller: _vetController, decoration: const InputDecoration(labelText: 'Veteriner', prefixIcon: Icon(Icons.person_outlined, color: AppColors.primaryGreen, size: 20))),
            const SizedBox(height: 12),
            TextFormField(controller: _costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ücret (₺)', prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryGreen, size: 20))),
            const SizedBox(height: 12),
            TextFormField(controller: _batchController, decoration: const InputDecoration(labelText: 'Parti/Lot No', prefixIcon: Icon(Icons.qr_code, color: AppColors.primaryGreen, size: 20))),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Aşı dropdown'ı için kategori başlıklarıyla gruplu item listesi.
  /// Başlık satırları disabled tutuldu — sadece görsel ayraç.
  List<DropdownMenuItem<String>> _buildVaccineDropdownItems() {
    final items = <DropdownMenuItem<String>>[];

    void addSection(String title, List<String> vaccines, Color accent) {
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__header_$title',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ));
      for (final v in vaccines) {
        items.add(DropdownMenuItem<String>(
          value: v,
          child: Text(v, overflow: TextOverflow.ellipsis),
        ));
      }
    }

    addSection('Zorunlu (Devlet)', AppConstants.mandatoryVaccines, AppColors.errorRed);
    addSection('Solunum Sistemi', AppConstants.respiratoryVaccines, AppColors.infoBlue);
    addSection('Doğum Öncesi (Anne)', AppConstants.prepartumVaccines, const Color(0xFF6A1B9A));
    addSection('Üreme', AppConstants.reproductiveVaccines, const Color(0xFFEF6C00));
    addSection('Buzağı', AppConstants.calfVaccines, const Color(0xFF558B2F));
    addSection('Diğer', AppConstants.otherVaccines, AppColors.textGrey);

    return items;
  }

  Future<DateTime?> _pickDate(DateTime init) => showDatePicker(
        context: context, initialDate: init, firstDate: DateTime(2020), lastDate: DateTime(2030),
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)), child: child!),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const SizedBox(height: 2),
            Text(date != null ? '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}' : 'Seçin',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: date != null ? AppColors.textDark : AppColors.textGrey)),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
      ]),
    );
  }
}
