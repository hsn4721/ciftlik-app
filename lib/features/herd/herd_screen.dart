import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/animal_model.dart';
import '../../data/repositories/animal_repository.dart';
import '../../core/subscription/feature_gate.dart';
import '../../core/subscription/subscription_constants.dart';
import 'add_animal_screen.dart';
import 'animal_detail_screen.dart';
import 'exited_animals_screen.dart';
import 'scan_tag_screen.dart';

class HerdScreen extends StatefulWidget {
  const HerdScreen({super.key});

  @override
  State<HerdScreen> createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> {
  final _repo = AnimalRepository();
  List<AnimalModel> _animals = [];
  List<AnimalModel> _filtered = [];
  String _selectedStatus = 'Tümü';
  String _searchQuery = '';
  bool _isLoading = true;

  // ─── Toplu seçim modu ──────────────────────────────────────
  final Set<int> _selectedIds = {};
  bool get _selectMode => _selectedIds.isNotEmpty;

  void _toggleSelect(AnimalModel a) {
    if (a.id == null) return;
    setState(() {
      if (_selectedIds.contains(a.id)) {
        _selectedIds.remove(a.id);
      } else {
        _selectedIds.add(a.id!);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  void _selectAll() => setState(() {
        _selectedIds
          ..clear()
          ..addAll(_filtered.map((a) => a.id).whereType<int>());
      });

  final List<String> _statuses = ['Tümü', AppConstants.animalMilking, 'Kuruda', AppConstants.animalPregnant, AppConstants.animalSick];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showActionMenu() {
    final user = AuthService.instance.currentUser;
    final canAdd = user?.canAddAnimal ?? true;
    final canRemove = user?.canRemoveAnimal ?? true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Sürü İşlemleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (canAdd)
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.primaryGreen, child: Icon(Icons.add, color: Colors.white)),
                title: const Text('Hayvan Ekle', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Sürüye yeni hayvan kaydet'),
                onTap: () async {
                  Navigator.pop(context);
                  // Hayvan limiti kontrolü — paket limit aştıysa paywall göster
                  if (!await FeatureGate.checkAnimalLimit(context, _animals.length)) return;
                  if (!mounted) return;
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAnimalScreen()));
                  if (result == true) _load();
                },
              ),
            if (canRemove)
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.errorRed, child: Icon(Icons.logout, color: Colors.white)),
                title: const Text('Hayvan Çıkar', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Satış, ölüm veya diğer nedenlerle çıkar'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveSheet();
                },
              ),
            if (!canAdd && !canRemove)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Bu işlem için yetkiniz yok', style: TextStyle(color: AppColors.textGrey)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRemoveSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RemoveAnimalSheet(
        animals: _animals,
        onRemoved: _load,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final animals = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _animals = animals;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.error('HerdScreen.load', e, st);
      if (!mounted) return;
      setState(() {
        _animals = [];
        _filtered = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sürü yüklenemedi. Lütfen tekrar deneyin.'),
          backgroundColor: AppColors.errorRed,
          action: SnackBarAction(
            label: 'Tekrar Dene',
            textColor: Colors.white,
            onPressed: _load,
          ),
        ),
      );
    }
  }

  void _applyFilter() {
    _filtered = _animals.where((a) {
      final matchStatus = _selectedStatus == 'Tümü' || a.status == _selectedStatus;
      final matchSearch = _searchQuery.isEmpty ||
          a.earTag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchStatus && matchSearch;
    }).toList();
  }

  // ─── Toplu işlem aksiyonları ──────────────────────────────

  Future<void> _bulkChangeStatus() async {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.canEditAnimal) return;
    final statuses = AppConstants.femaleStatuses;
    final newStatus = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Toplu Durum Değiştir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          ...statuses.map((s) => ListTile(
                leading: Icon(_statusIcon(s), color: _statusColor(s)),
                title: Text(s),
                onTap: () => Navigator.pop(ctx, s),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (newStatus == null) return;
    for (final id in _selectedIds) {
      final a = _animals.firstWhere((x) => x.id == id, orElse: () =>
          _animals.first);
      if (a.id != null) {
        await _repo.update(a.copyWith(status: newStatus));
      }
    }
    if (!mounted) return;
    final count = _selectedIds.length;
    _clearSelection();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count hayvan $newStatus olarak güncellendi'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  PreferredSizeWidget _buildSelectAppBar() {
    final user = AuthService.instance.currentUser;
    final canEdit = user?.canEditAnimal ?? false;
    final canRemove = user?.canRemoveAnimal ?? false;
    return AppBar(
      backgroundColor: AppColors.primaryGreen,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${_selectedIds.length} seçili'),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Tümünü Seç',
          onPressed: _selectAll,
        ),
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit_attributes),
            tooltip: 'Durum Değiştir',
            onPressed: _bulkChangeStatus,
          ),
        if (canRemove)
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Toplu Sil',
            onPressed: _bulkDelete,
          ),
      ],
    );
  }

  Future<void> _bulkDelete() async {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.canRemoveAnimal) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Toplu Silme'),
        content: Text(
          '$count hayvan kalıcı olarak silinecek. Bu işlem geri alınamaz.\n\n'
          'Satış/ölüm kaydı yerine çıkış belgelemek istiyorsanız hayvanı tek tek '
          '"Sürüden Çıkar" yöntemiyle işleyin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _selectedIds) {
      await _repo.delete(id);
    }
    if (!mounted) return;
    _clearSelection();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count hayvan silindi'),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Sağımda': return AppColors.infoBlue;
      case 'Kuruda': return AppColors.gold;
      case 'Gebe': return const Color(0xFF6A1B9A);
      case 'Hasta': return AppColors.errorRed;
      case 'Satılık': return AppColors.textGrey;
      default: return AppColors.primaryGreen;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Sağımda': return Icons.water_drop;
      case 'Kuruda': return Icons.pause_circle_outline;
      case 'Gebe': return Icons.child_friendly;
      case 'Hasta': return Icons.favorite;
      case 'Satılık': return Icons.sell;
      default: return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectMode ? _buildSelectAppBar() : AppBar(
        title: const Text('Sürü Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Küpe Tara',
            onPressed: () async {
              // QR tarama Pro özelliği
              if (!await FeatureGate.requireAccess(
                context, SubscriptionPlan.pro,
                featureName: 'QR/Barkod Tarama',
                reason: 'Küpe QR kodu ile hızlı hayvan arama Pro pakettedir.',
              )) return;
              if (!mounted) return;
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanTagScreen()));
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Çıkmış Hayvanlar',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExitedAnimalsScreen())),
          ),
        ],
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.herd),
          Column(
        children: [
          // Özet bar
          Container(
            color: AppColors.primaryGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SummaryChip(label: 'Toplam', count: _animals.length, color: Colors.white),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Sağımda', count: _animals.where((a) => a.status == AppConstants.animalMilking).length, color: Colors.lightBlueAccent),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Kuruda', count: _animals.where((a) => a.status == AppConstants.animalDry).length, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Gebe', count: _animals.where((a) => a.status == AppConstants.animalPregnant).length, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Hasta', count: _animals.where((a) => a.status == AppConstants.animalSick).length, color: Colors.redAccent),
                ],
              ),
            ),
          ),
          // Arama
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
              decoration: InputDecoration(
                hintText: 'Küpe no veya isim ara...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchQuery = ''; _applyFilter(); }))
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Durum filtre
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = _selectedStatus == s;
                return GestureDetector(
                  onTap: () => setState(() { _selectedStatus = s; _applyFilter(); }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.divider),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Liste
          Expanded(
            child: _isLoading
                ? const SkeletonList(itemCount: 8, itemHeight: 80)
                : _filtered.isEmpty
                    ? RefreshIndicator(
                        color: AppColors.primaryGreen,
                        onRefresh: _load,
                        child: ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.35), const _EmptyState()]),
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryGreen,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final animal = _filtered[i];
                            final isSelected = animal.id != null &&
                                _selectedIds.contains(animal.id);
                            return _AnimalCard(
                              animal: animal,
                              statusColor: _statusColor(animal.status),
                              statusIcon: _statusIcon(animal.status),
                              selected: isSelected,
                              onLongPress: () => _toggleSelect(animal),
                              onTap: () async {
                                if (_selectMode) {
                                  _toggleSelect(animal);
                                  return;
                                }
                                await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AnimalDetailScreen(animal: animal)));
                                _load();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
          ),
        ],
      ),
      floatingActionButton: Builder(builder: (_) {
        final u = AuthService.instance.currentUser;
        // Hayvan ekleme veya çıkışı yapabilen bir kullanıcı değilse FAB gösterme
        if (u != null && !u.canAddAnimal && !u.canRemoveAnimal) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: _showActionMenu,
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.menu, color: Colors.white),
          label: const Text('İşlem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      }),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text('$count', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final AnimalModel animal;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  const _AnimalCard({
    required this.animal,
    required this.statusColor,
    required this.statusIcon,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppColors.primaryGreen, width: 2)
              : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              ),
            ),
            const SizedBox(width: 14),
            animal.photoPath != null
                ? ClipOval(
                    child: Image.file(File(animal.photoPath!), width: 50, height: 50, fit: BoxFit.cover),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          animal.name ?? animal.earTag,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        if (animal.name != null) ...[
                          const SizedBox(width: 6),
                          Text('• ${animal.earTag}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(animal.breed, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        const Text(' • ', style: TextStyle(color: AppColors.textGrey)),
                        Text(animal.ageDisplay, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        const Text(' • ', style: TextStyle(color: AppColors.textGrey)),
                        Text(animal.gender, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(animal.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 80, color: Color(0x4D1B5E20)),
          SizedBox(height: 16),
          Text('Henüz hayvan eklenmedi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
          SizedBox(height: 8),
          Text('İşlem butonuna basarak ilk hayvanınızı ekleyin', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

// ─── Hayvan Çıkar Sheet ──────────────────────────────────────────────────────

class _RemoveAnimalSheet extends StatefulWidget {
  final List<AnimalModel> animals;
  final VoidCallback onRemoved;
  const _RemoveAnimalSheet({required this.animals, required this.onRemoved});

  @override
  State<_RemoveAnimalSheet> createState() => _RemoveAnimalSheetState();
}

class _RemoveAnimalSheetState extends State<_RemoveAnimalSheet> {
  final _repo = AnimalRepository();
  final _priceCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  AnimalModel? _selected;
  String? _reason;
  bool _saving = false;
  String _search = '';

  List<AnimalModel> get _filtered => widget.animals
      .where((a) =>
          a.earTag.toLowerCase().contains(_search.toLowerCase()) ||
          (a.name?.toLowerCase().contains(_search.toLowerCase()) ?? false))
      .toList();

  @override
  void dispose() {
    _priceCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected == null || _reason == null) return;
    if (_reason == 'Satış' && (_priceCtrl.text.isEmpty || double.tryParse(_priceCtrl.text.replaceAll(',', '.')) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış fiyatı giriniz'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final price = _reason == 'Satış'
          ? double.tryParse(_priceCtrl.text.replaceAll(',', '.'))
          : null;
      await _repo.removeAnimal(
        animal: _selected!,
        reason: _reason!,
        exitPrice: price,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRemoved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selected!.earTag} sürüden çıkarıldı ($_reason)'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = AppConstants.removalReasons;
    final reasonIcons = {
      'Satış': Icons.sell,
      'Ölüm': Icons.heart_broken,
      'Kesim': Icons.cut,
      'Hibe': Icons.volunteer_activism,
      'Kayıp': Icons.search_off,
      'Diğer': Icons.more_horiz,
    };
    final reasonColors = {
      'Satış': AppColors.primaryGreen,
      'Ölüm': AppColors.errorRed,
      'Kesim': const Color(0xFF37474F),
      'Hibe': AppColors.infoBlue,
      'Kayıp': AppColors.gold,
      'Diğer': AppColors.textGrey,
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Hayvan Çıkar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Sürüden ayrılan hayvanı kaydedin', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ── Hayvan Seç ──────────────────────────────────────────────
                const Text('Hayvan Seç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Küpe no veya isim ara...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                ..._filtered.map((a) {
                  final sel = _selected?.id == a.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.primaryGreen : AppColors.divider,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pets, color: sel ? AppColors.primaryGreen : AppColors.textGrey, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.earTag, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: sel ? AppColors.primaryGreen : AppColors.textDark)),
                                if (a.name != null) Text(a.name!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                          Text(a.status, style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          if (sel) const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // ── Çıkış Nedeni ─────────────────────────────────────────────
                const Text('Çıkış Nedeni', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    final sel = _reason == r;
                    final color = reasonColors[r] ?? AppColors.textGrey;
                    return GestureDetector(
                      onTap: () => setState(() => _reason = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? color.withValues(alpha: 0.12) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? color : AppColors.divider, width: sel ? 2 : 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(reasonIcons[r] ?? Icons.help_outline, color: sel ? color : AppColors.textGrey, size: 18),
                            const SizedBox(width: 6),
                            Text(r, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: sel ? color : AppColors.textGrey)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ── Satış Fiyatı ─────────────────────────────────────────────
                if (_reason == 'Satış') ...[
                  const SizedBox(height: 16),
                  const Text('Satış Fiyatı', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Satış Fiyatı (₺) *',
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryGreen, size: 20),
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Finansa otomatik gelir kaydı oluşturulacak', style: TextStyle(fontSize: 11, color: AppColors.primaryGreen)),
                ],
                const SizedBox(height: 24),

                // ── Onayla ───────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selected != null && _reason != null && !_saving) ? _confirm : null,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, color: Colors.white),
                    label: Text(_saving ? 'Kaydediliyor...' : 'Çıkışı Onayla',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
