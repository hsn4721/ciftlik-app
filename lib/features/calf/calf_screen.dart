import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/calf_model.dart';
import '../../data/models/animal_model.dart';
import '../../data/repositories/calf_repository.dart';
import '../../data/repositories/animal_repository.dart';
import '../../shared/widgets/empty_state.dart';

class CalfScreen extends StatefulWidget {
  const CalfScreen({super.key});

  @override
  State<CalfScreen> createState() => _CalfScreenState();
}

class _CalfScreenState extends State<CalfScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _calfRepo = CalfRepository();
  final _animalRepo = AnimalRepository();

  List<CalfModel> _calves = [];
  List<BreedingModel> _breedings = [];
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
      final calves = await _calfRepo.getAllCalves();
      final breedings = await _calfRepo.getAllBreedings();
      setState(() {
        _calves = calves;
        _breedings = breedings;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCalf(CalfModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buzağı Sil'),
        content: Text('${c.earTag} numaralı buzağı kaydı silinsin mi?'),
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
      await _calfRepo.deleteCalf(c.id!);
      _load();
    }
  }

  Future<void> _addCalf() async {
    final animals = await _animalRepo.getAll();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddCalfScreen(animals: animals)));
    _load();
  }

  Future<void> _addBreeding() async {
    final animals = await _animalRepo.getByStatus(AppConstants.animalMilking);
    final pregnant = await _animalRepo.getByStatus(AppConstants.animalPregnant);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddBreedingScreen(animals: [...animals, ...pregnant]),
    ));
    _load();
  }

  Future<void> _deleteBreeding(BreedingModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kayıt Sil'),
        content: Text('${b.animalEarTag ?? ''} hayvanının tohumlama kaydı silinsin mi?'),
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
      await _calfRepo.deleteBreeding(b.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcomingBirths = _breedings.where((b) {
      final days = b.daysUntilBirth;
      return b.status == AppConstants.breedingPregnant && days != null && days <= 30 && days >= 0;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buzağı & Üreme'),
        actions: [
          if (upcomingBirths > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('$upcomingBirths Yakın Doğum', style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.gold,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Buzağılar'), Tab(text: 'Üreme Takibi')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tab.index == 0 ? _addCalf : _addBreeding,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tab.index == 0 ? 'Buzağı Ekle' : 'Tohumlama Ekle',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.calf),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _CalvesTab(calves: _calves, onDelete: _deleteCalf, onRefresh: _load),
                      _BreedingTab(breedings: _breedings, onDelete: _deleteBreeding, onRefresh: _load),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── CALVES TAB ───────────────────────────────────────

class _CalvesTab extends StatelessWidget {
  final List<CalfModel> calves;
  final Function(CalfModel) onDelete;
  final VoidCallback onRefresh;

  const _CalvesTab({required this.calves, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (calves.isEmpty) {
      return const EmptyState(
        icon: Icons.baby_changing_station,
        title: 'Buzağı Yok',
        subtitle: 'Henüz buzağı kaydı eklenmemiş.\nSağ alttaki butona basarak ekleyebilirsiniz.',
      );
    }

    final Map<String, List<CalfModel>> grouped = {};
    for (final c in calves) {
      grouped.putIfAbsent(c.status, () => []).add(c);
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: '${entry.key} (${entry.value.length})', color: _statusColor(entry.key)),
              ...entry.value.map((c) => _CalfCard(calf: c, onDelete: onDelete)),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Sağlıklı': return AppColors.primaryGreen;
      case 'Hasta': return AppColors.errorRed;
      case 'Sütten Kesildi': return AppColors.infoBlue;
      case 'Satıldı': return AppColors.textGrey;
      default: return AppColors.primaryGreen;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color.withOpacity(0.08),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
    );
  }
}

class _CalfCard extends StatelessWidget {
  final CalfModel calf;
  final Function(CalfModel) onDelete;
  const _CalfCard({required this.calf, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isMale = calf.gender == AppConstants.male;
    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: isMale ? AppColors.infoBlue : Colors.pink.shade300, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMale ? AppColors.infoBlue.withOpacity(0.1) : Colors.pink.shade50,
          child: Text(isMale ? '♂' : '♀', style: TextStyle(color: isMale ? AppColors.infoBlue : Colors.pink.shade400, fontSize: 18)),
        ),
        title: Text(calf.earTag, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (calf.name != null) Text(calf.name!, style: const TextStyle(fontSize: 12)),
          Text('${calf.ageDisplay} • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(calf.birthDate))}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          if (calf.motherEarTag != null)
            Text('Anne: ${calf.motherEarTag}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.textGrey),
          onPressed: () => onDelete(calf),
        ),
      ),
    );
  }
}

// ─── BREEDING TAB ─────────────────────────────────────

class _BreedingTab extends StatelessWidget {
  final List<BreedingModel> breedings;
  final Function(BreedingModel) onDelete;
  final VoidCallback onRefresh;

  const _BreedingTab({required this.breedings, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (breedings.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'Tohumlama Kaydı Yok',
        subtitle: 'Henüz tohumlama kaydı eklenmemiş.\nSağ alttaki butona basarak ekleyebilirsiniz.',
      );
    }

    final upcoming = breedings.where((b) {
      final d = b.daysUntilBirth;
      return b.status == AppConstants.breedingPregnant && d != null && d >= 0 && d <= 30;
    }).toList();
    final others = breedings.where((b) => !upcoming.contains(b)).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(title: 'Yaklaşan Doğumlar (${upcoming.length})', color: AppColors.gold),
            ...upcoming.map((b) => _BreedingCard(breeding: b, onDelete: onDelete, highlight: true)),
            const SizedBox(height: 8),
          ],
          if (others.isNotEmpty) ...[
            _SectionHeader(title: 'Tüm Kayıtlar (${others.length})', color: AppColors.primaryGreen),
            ...others.map((b) => _BreedingCard(breeding: b, onDelete: onDelete, highlight: false)),
          ],
        ],
      ),
    );
  }
}

class _BreedingCard extends StatelessWidget {
  final BreedingModel breeding;
  final Function(BreedingModel) onDelete;
  final bool highlight;

  const _BreedingCard({required this.breeding, required this.onDelete, required this.highlight});

  Color _statusColor(String status) {
    switch (status) {
      case 'Gebe': return AppColors.primaryGreen;
      case 'Tohumlandı': return AppColors.infoBlue;
      case 'Doğurdu': return AppColors.gold;
      default: return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(breeding.status);
    final days = breeding.daysUntilBirth;
    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: highlight ? AppColors.gold : color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                breeding.animalEarTag ?? 'Bilinmiyor',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(breeding.status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onDelete(breeding),
              child: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 20),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${breeding.breedingType} • ${breeding.breedingDate}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          if (breeding.expectedBirthDate != null)
            Text('Tahmini Doğum: ${breeding.expectedBirthDate}',
              style: TextStyle(fontSize: 12, color: days != null && days <= 30 ? AppColors.gold : AppColors.textGrey,
                fontWeight: days != null && days <= 30 ? FontWeight.w600 : FontWeight.normal)),
          if (days != null && days >= 0)
            Text('$days gün kaldı', style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w700)),
          if (breeding.bullBreed != null)
            Text('Boğa: ${breeding.bullBreed}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CALF SCREEN
// ─────────────────────────────────────────────

class AddCalfScreen extends StatefulWidget {
  final List<AnimalModel> animals;
  const AddCalfScreen({super.key, required this.animals});

  @override
  State<AddCalfScreen> createState() => _AddCalfScreenState();
}

class _AddCalfScreenState extends State<AddCalfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CalfRepository();
  final _earTagCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _gender = AppConstants.female;
  String _status = AppConstants.calfHealthy;
  AnimalModel? _mother;
  DateTime _birthDate = DateTime.now();
  bool _saving = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _birthDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = CalfModel(
      earTag: _earTagCtrl.text.trim(),
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      gender: _gender,
      birthDate: DateFormat('yyyy-MM-dd').format(_birthDate),
      motherId: _mother?.id,
      birthWeight: _weightCtrl.text.isEmpty ? null : double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
      status: _status,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insertCalf(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  void dispose() {
    _earTagCtrl.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buzağı Kaydı Ekle')),
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
                    controller: _earTagCtrl,
                    decoration: const InputDecoration(labelText: 'Kulak No *'),
                    validator: (v) => v == null || v.isEmpty ? 'Kulak numarası giriniz' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'İsim (İsteğe Bağlı)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Cinsiyet'),
                    items: [AppConstants.female, AppConstants.male]
                        .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: [AppConstants.calfHealthy, AppConstants.calfSick, AppConstants.calfWeaned, AppConstants.calfSold]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Doğum Tarihi', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                      child: Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(_birthDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.animals.isNotEmpty)
                    DropdownButtonFormField<AnimalModel>(
                      value: _mother,
                      decoration: const InputDecoration(labelText: 'Anne (İsteğe Bağlı)'),
                      items: widget.animals
                          .where((a) => a.gender == AppConstants.female)
                          .map((a) => DropdownMenuItem(value: a, child: Text('${a.earTag} ${a.name ?? ''}')))
                          .toList(),
                      onChanged: (v) => setState(() => _mother = v),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightCtrl,
                    decoration: const InputDecoration(labelText: 'Doğum Ağırlığı (kg)', hintText: 'Boş bırakılabilir'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    : const Text('Buzağı Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD BREEDING SCREEN
// ─────────────────────────────────────────────

class AddBreedingScreen extends StatefulWidget {
  final List<AnimalModel> animals;
  const AddBreedingScreen({super.key, required this.animals});

  @override
  State<AddBreedingScreen> createState() => _AddBreedingScreenState();
}

class _AddBreedingScreenState extends State<AddBreedingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CalfRepository();
  AnimalModel? _selectedAnimal;
  String _breedingType = AppConstants.breedingTypes.first;
  String _status = AppConstants.breedingInseminated;
  final _bullBreedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _breedingDate = DateTime.now();
  DateTime? _expectedBirthDate;
  bool _saving = false;

  Future<void> _pickBreedingDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _breedingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _breedingDate = d;
        _expectedBirthDate = d.add(const Duration(days: 283));
      });
    }
  }

  Future<void> _pickExpectedDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expectedBirthDate ?? _breedingDate.add(const Duration(days: 283)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 400)),
    );
    if (d != null) setState(() => _expectedBirthDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAnimal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hayvan seçiniz')));
      return;
    }
    setState(() => _saving = true);
    final model = BreedingModel(
      animalId: _selectedAnimal!.id!,
      breedingType: _breedingType,
      breedingDate: DateFormat('yyyy-MM-dd').format(_breedingDate),
      bullBreed: _bullBreedCtrl.text.trim().isEmpty ? null : _bullBreedCtrl.text.trim(),
      expectedBirthDate: _expectedBirthDate != null ? DateFormat('yyyy-MM-dd').format(_expectedBirthDate!) : null,
      status: _status,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insertBreeding(model);
      if (model.expectedBirthDate != null && _selectedAnimal != null) {
        final expectedDate = DateTime.tryParse(model.expectedBirthDate!);
        if (expectedDate != null) {
          await NotificationService.instance.scheduleBirthReminder(
            id: model.createdAt.hashCode.abs(),
            animalName: _selectedAnimal!.name ?? _selectedAnimal!.earTag,
            expectedDate: expectedDate,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  void dispose() {
    _bullBreedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tohumlama Kaydı')),
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
                  DropdownButtonFormField<AnimalModel>(
                    value: _selectedAnimal,
                    decoration: const InputDecoration(labelText: 'Hayvan *'),
                    items: widget.animals
                        .map((a) => DropdownMenuItem(value: a, child: Text('${a.earTag} ${a.name ?? ''}')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAnimal = v),
                    validator: (v) => v == null ? 'Hayvan seçiniz' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _breedingType,
                    decoration: const InputDecoration(labelText: 'Tohumlama Tipi'),
                    items: AppConstants.breedingTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _breedingType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: [AppConstants.breedingInseminated, AppConstants.breedingPregnant,
                            AppConstants.breedingCalved, AppConstants.breedingOpen]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickBreedingDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Tohumlama Tarihi', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                      child: Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(_breedingDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickExpectedDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tahmini Doğum Tarihi',
                        hintText: 'Otomatik hesaplandı (283 gün)',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _expectedBirthDate != null
                            ? DateFormat('dd MMMM yyyy', 'tr_TR').format(_expectedBirthDate!)
                            : 'Tohumlama tarihi seçin',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bullBreedCtrl,
                    decoration: const InputDecoration(labelText: 'Boğa / Sperm Irk Bilgisi', hintText: 'Boş bırakılabilir'),
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
                    : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
