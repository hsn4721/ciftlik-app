import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/animal_model.dart';
import '../../data/repositories/animal_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/masked_amount.dart';

/// Çiftlikten çıkmış hayvanların arşivi.
/// Satış / Ölüm / Kesim / Hibe / Kayıp nedenlerine göre filtreleme + arama.
class ExitedAnimalsScreen extends StatefulWidget {
  const ExitedAnimalsScreen({super.key});

  @override
  State<ExitedAnimalsScreen> createState() => _ExitedAnimalsScreenState();
}

class _ExitedAnimalsScreenState extends State<ExitedAnimalsScreen> {
  final _repo = AnimalRepository();
  List<AnimalModel> _all = [];
  List<AnimalModel> _filtered = [];
  String _filter = 'Tümü';
  String _query = '';
  bool _loading = true;

  static const _filters = ['Tümü', 'Satıldı', 'Öldü', 'Kesime Gitti'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getRemoved();
      if (!mounted) return;
      setState(() {
        _all = list;
        _apply();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply() {
    _filtered = _all.where((a) {
      final matchFilter = _filter == 'Tümü' || a.status == _filter;
      final matchSearch = _query.isEmpty ||
          a.earTag.toLowerCase().contains(_query.toLowerCase()) ||
          (a.name?.toLowerCase().contains(_query.toLowerCase()) ?? false);
      return matchFilter && matchSearch;
    }).toList();
  }

  Color _exitColor(String status) {
    switch (status) {
      case AppConstants.animalSold:        return AppColors.primaryGreen;
      case AppConstants.animalDead:        return AppColors.errorRed;
      case AppConstants.animalSlaughtered: return const Color(0xFF8D6E63);
      default: return AppColors.textGrey;
    }
  }

  IconData _exitIcon(String status) {
    switch (status) {
      case AppConstants.animalSold:        return Icons.sell_outlined;
      case AppConstants.animalDead:        return Icons.heart_broken;
      case AppConstants.animalSlaughtered: return Icons.cut;
      default: return Icons.logout;
    }
  }

  double get _totalSaleIncome {
    return _all
        .where((a) => a.status == AppConstants.animalSold)
        .fold<double>(0, (sum, a) => sum + (a.exitPrice ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'tr_TR');
    final soldCount = _all.where((a) => a.status == AppConstants.animalSold).length;
    final deadCount = _all.where((a) => a.status == AppConstants.animalDead).length;
    final slaCount  = _all.where((a) => a.status == AppConstants.animalSlaughtered).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Çıkmış Hayvanlar')),
      body: Column(children: [
        // Özet bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(children: [
            Row(children: [
              Expanded(child: _StatCell(
                label: 'Satış', value: '$soldCount',
                color: AppColors.primaryGreen, icon: Icons.sell_outlined,
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatCell(
                label: 'Ölüm', value: '$deadCount',
                color: AppColors.errorRed, icon: Icons.heart_broken,
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatCell(
                label: 'Kesim', value: '$slaCount',
                color: const Color(0xFF8D6E63), icon: Icons.cut,
              )),
            ]),
            if (_totalSaleIncome > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.payments, color: AppColors.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  const Text('Toplam Satış Geliri',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  const Spacer(),
                  MaskedAmount(
                    text: '₺${fmt.format(_totalSaleIncome)}',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const Divider(height: 1),

        // Arama + Filtre
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() { _query = v; _apply(); }),
            decoration: InputDecoration(
              hintText: 'Küpe / isim ara...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = f == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() { _filter = f; _apply(); }),
                  selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primaryGreen,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Liste
        Expanded(
          child: _loading
              ? const SkeletonList(itemCount: 6, itemHeight: 80)
              : _filtered.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        const EmptyState(
                          icon: Icons.history,
                          title: 'Çıkmış Hayvan Yok',
                          subtitle: 'Satış, ölüm veya kesim nedenleriyle\nçıkarılan hayvanlar burada görünür.',
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final a = _filtered[i];
                          final color = _exitColor(a.status);
                          final icon = _exitIcon(a.status);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(left: BorderSide(color: color, width: 4)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Row(children: [
                                Expanded(child: Text(a.earTag,
                                    style: const TextStyle(fontWeight: FontWeight.w800))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(a.status,
                                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                                ),
                              ]),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (a.name != null) Text(a.name!, style: const TextStyle(fontSize: 12)),
                                Text('${a.breed} · ${a.gender}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                if (a.exitDate != null)
                                  Text('Çıkış: ${a.exitDate}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                if (a.exitPrice != null && a.status == AppConstants.animalSold)
                                  MaskedAmount(
                                    text: 'Satış: ₺${fmt.format(a.exitPrice!)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          Text(value, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: color,
          )),
        ])),
      ]),
    );
  }
}
