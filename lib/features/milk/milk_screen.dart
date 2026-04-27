import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../data/models/milking_model.dart';
import '../../data/models/bulk_milking_model.dart';
import '../../data/repositories/milking_repository.dart';
import '../../data/repositories/bulk_milking_repository.dart';
import '../../data/repositories/tank_repository.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/models/animal_model.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/services/auth_service.dart';

class MilkScreen extends StatefulWidget {
  const MilkScreen({super.key});

  @override
  State<MilkScreen> createState() => _MilkScreenState();
}

class _MilkScreenState extends State<MilkScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bulkRepo = BulkMilkingRepository();
  final _milkRepo = MilkingRepository();
  final _tankRepo = TankRepository();

  List<BulkMilkingModel> _todayBulk = [];
  List<MilkingModel> _todayIndividual = [];
  List<TankLogModel> _tankLogs = [];
  Map<String, double> _weeklyTotals = {};
  double _todayTotal = 0;
  double _monthTotal = 0;
  double _tankBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final today = DateTime.now().toIso8601String().split('T').first;
      final results = await Future.wait([
        _bulkRepo.getByDate(today),
        _milkRepo.getByDate(today),
        _tankRepo.getLogs(limit: 30),
        _bulkRepo.getDailyTotals(7),
        _bulkRepo.getTodayTotal(),
        _bulkRepo.getMonthTotal(),
        _tankRepo.getCurrentBalance(),
      ]);
      final indivToday = await _milkRepo.getTodayTotal();
      final indivMonth = await _milkRepo.getMonthTotal();
      setState(() {
        _todayBulk = results[0] as List<BulkMilkingModel>;
        _todayIndividual = results[1] as List<MilkingModel>;
        _tankLogs = results[2] as List<TankLogModel>;
        _weeklyTotals = results[3] as Map<String, double>;
        _todayTotal = (results[4] as double) + indivToday;
        _monthTotal = (results[5] as double) + indivMonth;
        _tankBalance = results[6] as double;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Süt kayıtları yüklenemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Sağım Türü Seç',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _SheetOption(
              icon: Icons.group,
              iconColor: AppColors.primaryGreen,
              title: 'Toplu Sağım',
              subtitle: 'Sabah/akşam öğün bazlı kayıt — hayvan seçmeden',
              onTap: () async {
                Navigator.pop(context);
                final ok = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BulkMilkingScreen()));
                if (ok == true) _load();
              },
            ),
            _SheetOption(
              icon: Icons.pets,
              iconColor: AppColors.infoBlue,
              title: 'Bireysel Sağım',
              subtitle: 'Tek hayvan için detaylı kayıt',
              onTap: () async {
                Navigator.pop(context);
                final ok = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddMilkingScreen()));
                if (ok == true) _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Süt Takibi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Tank'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.milk),
          _isLoading
          ? const SkeletonList(itemCount: 8, itemHeight: 72)
          : Column(
              children: [
                _SummaryBar(
                    todayTotal: _todayTotal,
                    monthTotal: _monthTotal,
                    tankBalance: _tankBalance),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DailyTab(
                        bulkRecords: _todayBulk,
                        individualRecords: _todayIndividual,
                        onRefresh: _load,
                      ),
                      _WeeklyTab(totals: _weeklyTotals),
                      _TankTab(
                        balance: _tankBalance,
                        logs: _tankLogs,
                        onAction: _load,
                        tankRepo: _tankRepo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: Builder(builder: (_) {
        final u = AuthService.instance.currentUser;
        if (u != null && !u.canAddMilking) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: _showAddSheet,
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Sağım Gir',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        );
      }),
    );
  }
}

// ─── ÖZET BAR ───────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double todayTotal;
  final double monthTotal;
  final double tankBalance;
  const _SummaryBar(
      {required this.todayTotal, required this.monthTotal, required this.tankBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryGreen,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(child: _SumCard(label: 'Bugün', value: '${todayTotal.toStringAsFixed(1)} L', icon: Icons.today)),
          const SizedBox(width: 8),
          Expanded(child: _SumCard(label: 'Bu Ay', value: '${monthTotal.toStringAsFixed(1)} L', icon: Icons.calendar_month)),
          const SizedBox(width: 8),
          Expanded(
            child: _SumCard(
              label: 'Tankta',
              value: '${tankBalance.toStringAsFixed(1)} L',
              icon: Icons.water,
              highlight: tankBalance > 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  const _SumCard({required this.label, required this.value, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── GÜNLÜK TAB ─────────────────────────────────────────

class _DailyTab extends StatelessWidget {
  final List<BulkMilkingModel> bulkRecords;
  final List<MilkingModel> individualRecords;
  final VoidCallback onRefresh;
  const _DailyTab(
      {required this.bulkRecords, required this.individualRecords, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (bulkRecords.isEmpty && individualRecords.isEmpty) {
      return const EmptyState(
        icon: Icons.water_drop_outlined,
        title: 'Bugün sağım kaydı yok',
        subtitle: 'Aşağıdaki butona basarak sağım kaydı girebilirsiniz',
      );
    }

    final morningBulk = bulkRecords.where((r) => r.session == 'Sabah').toList();
    final eveningBulk = bulkRecords.where((r) => r.session == 'Akşam').toList();
    final morningIndiv = individualRecords.where((r) => r.session == 'Sabah').toList();
    final eveningIndiv = individualRecords.where((r) => r.session == 'Akşam').toList();

    final morningTotal = morningBulk.fold(0.0, (s, r) => s + r.totalAmount) +
        morningIndiv.fold(0.0, (s, r) => s + r.amount);
    final eveningTotal = eveningBulk.fold(0.0, (s, r) => s + r.totalAmount) +
        eveningIndiv.fold(0.0, (s, r) => s + r.amount);

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _SessionSummaryCard(
                session: 'Sabah', total: morningTotal,
                animalCount: morningBulk.fold(0, (s, r) => s + r.animalCount) + morningIndiv.length,
                color: AppColors.gold)),
            const SizedBox(width: 12),
            Expanded(child: _SessionSummaryCard(
                session: 'Akşam', total: eveningTotal,
                animalCount: eveningBulk.fold(0, (s, r) => s + r.animalCount) + eveningIndiv.length,
                color: AppColors.infoBlue)),
          ]),
          if (bulkRecords.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Toplu Sağım', icon: Icons.group),
            const SizedBox(height: 8),
            ...bulkRecords.map((r) => _BulkMilkTile(record: r, onDelete: onRefresh)),
          ],
          if (individualRecords.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Bireysel Sağım', icon: Icons.pets),
            const SizedBox(height: 8),
            ...individualRecords.map((r) => _IndividualMilkTile(record: r, onDelete: onRefresh)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textGrey),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
    ]);
  }
}

class _SessionSummaryCard extends StatelessWidget {
  final String session;
  final double total;
  final int animalCount;
  final Color color;
  const _SessionSummaryCard(
      {required this.session, required this.total, required this.animalCount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(session == 'Sabah' ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: color, size: 18),
          const SizedBox(width: 6),
          Text(session, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        Text('${total.toStringAsFixed(1)} L',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        Text('$animalCount inek', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ]),
    );
  }
}

class _BulkMilkTile extends StatelessWidget {
  final BulkMilkingModel record;
  final VoidCallback onDelete;
  const _BulkMilkTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isMorning = record.session == 'Sabah';
    final color = isMorning ? AppColors.gold : AppColors.infoBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: color, size: 20),
        ),
        title: Text('${record.session} Sağım — ${record.animalCount} inek',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: record.notes != null
            ? Text(record.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${record.totalAmount.toStringAsFixed(1)} L',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Kaydı Sil'),
                  content: const Text('Bu sağım kaydı silinecek. Tank miktarı da düzeltilecek.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sil', style: TextStyle(color: AppColors.errorRed)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await BulkMilkingRepository().delete(record.id!, record.totalAmount);
                onDelete();
              }
            },
            child: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 18),
          ),
        ]),
      ),
    );
  }
}

class _IndividualMilkTile extends StatelessWidget {
  final MilkingModel record;
  final VoidCallback onDelete;
  const _IndividualMilkTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isMorning = record.session == 'Sabah';
    final color = isMorning ? AppColors.gold : AppColors.infoBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              color: color, size: 20),
        ),
        title: Text(record.animalName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text('${record.session} · ${record.animalEarTag}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${record.amount.toStringAsFixed(1)} L',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await MilkingRepository().delete(record.id!);
              onDelete();
            },
            child: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 18),
          ),
        ]),
      ),
    );
  }
}

// ─── HAFTALIK TAB ───────────────────────────────────────

class _WeeklyTab extends StatelessWidget {
  final Map<String, double> totals;
  const _WeeklyTab({required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Henüz veri yok',
        subtitle: 'Sağım kaydı girdikçe haftalık trend burada görünecek',
      );
    }

    final maxVal = totals.values.reduce((a, b) => a > b ? a : b);
    final entries = totals.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Son 7 Gün Üretim',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: entries.map((e) {
                  final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                  final parts = e.key.split('-');
                  final label = '${parts[2]}.${parts[1]}';
                  return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${e.value.toStringAsFixed(0)}L',
                        style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 32,
                      height: (ratio * 120).clamp(4.0, 120.0),
                      decoration: BoxDecoration(
                          color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ]);
                }).toList(),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ...entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.key, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            Text('${e.value.toStringAsFixed(1)} L',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen)),
          ]),
        )),
      ],
    );
  }
}

// ─── TANK TAB ───────────────────────────────────────────

class _TankTab extends StatelessWidget {
  final double balance;
  final List<TankLogModel> logs;
  final VoidCallback onAction;
  final TankRepository tankRepo;
  const _TankTab(
      {required this.balance, required this.logs, required this.onAction, required this.tankRepo});

  void _showDeductSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
          final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
          final total = amount * price;
          return Padding(
            padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Süt Satışı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Mevcut: ${balance.toStringAsFixed(1)} L',
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                  labelText: 'Satılan Miktar (Litre)',
                  prefixIcon: Icon(Icons.water_drop_outlined, color: AppColors.errorRed),
                  suffixText: 'L',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                  labelText: 'Birim Fiyat (₺/L) — opsiyonel',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryGreen),
                  suffixText: '₺/L',
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Toplam Gelir: ₺${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
                    const Spacer(),
                    const Text('Finansa yazılacak', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (alıcı adı vb.)',
                  prefixIcon: Icon(Icons.notes, color: AppColors.textGrey),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                    if (amt == null || amt <= 0) return;
                    final unitPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                    await tankRepo.deduct(amt,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      unitPrice: unitPrice,
                    );
                    Navigator.pop(ctx);
                    onAction();
                  },
                  child: const Text('Satışı Kaydet',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tankı Sıfırla'),
        content: Text('Tank miktarı (${balance.toStringAsFixed(1)} L) sıfırlanacak. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              await tankRepo.resetTank();
              Navigator.pop(context);
              onAction();
            },
            child: const Text('Sıfırla', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tank durumu kartı
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: balance > 0
                  ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
                  : [AppColors.textGrey, AppColors.divider],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            const Icon(Icons.water, color: Colors.white70, size: 32),
            const SizedBox(height: 8),
            const Text('Soğutma Tankı', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${balance.toStringAsFixed(1)} L',
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: balance > 0 ? () => _showDeductSheet(context) : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Satış Yap', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: balance > 0 ? () => _confirmReset(context) : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Sıfırla', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Tank Hareketleri',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Henüz hareket yok',
                  style: TextStyle(color: AppColors.textGrey)),
            ),
          )
        else
          ...logs.map((log) => _TankLogTile(log: log)),
      ],
    );
  }
}

class _TankLogTile extends StatelessWidget {
  final TankLogModel log;
  const _TankLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isAdd = log.amount > 0;
    final color = isAdd ? AppColors.primaryGreen : AppColors.errorRed;
    final icon = switch (log.type) {
      'Satış' => Icons.sell_outlined,
      'Sıfırlama' => Icons.refresh,
      _ => Icons.water_drop_outlined,
    };
    final df = DateFormat('dd.MM.yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (log.notes != null)
            Text(log.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          Text(df.format(DateTime.parse(log.date)),
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isAdd ? '+' : ''}${log.amount.toStringAsFixed(1)} L',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text('Bakiye: ${log.balanceAfter.toStringAsFixed(1)} L',
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
        ]),
      ]),
    );
  }
}

// ─── SHEET OPTION ───────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon, required this.iconColor, required this.title,
       required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
      onTap: onTap,
    );
  }
}

// ─── TOPLU SAĞIM EKRANI ─────────────────────────────────

class BulkMilkingScreen extends StatefulWidget {
  const BulkMilkingScreen({super.key});

  @override
  State<BulkMilkingScreen> createState() => _BulkMilkingScreenState();
}

class _BulkMilkingScreenState extends State<BulkMilkingScreen> {
  final _repo = BulkMilkingRepository();
  final _animalCountCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _session = 'Sabah';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _animalCountCtrl.dispose();
    _totalAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final count = int.tryParse(_animalCountCtrl.text);
    final amount = double.tryParse(_totalAmountCtrl.text.replaceAll(',', '.'));
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir hayvan sayısı girin')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir süt miktarı girin')));
      return;
    }
    setState(() => _saving = true);
    final model = BulkMilkingModel(
      session: _session,
      date: _date.toIso8601String().split('T').first,
      animalCount: count,
      totalAmount: amount,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insert(model);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toplu sağım kaydedilemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toplu Sağım Girişi'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bilgi kutusu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tek bir öğünde sağılan toplam hayvan sayısını ve toplam süt miktarını girin.',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryGreen, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Öğün seçimi
          _Card(
            title: 'Sağım Öğünü',
            child: Row(
              children: ['Sabah', 'Akşam'].map((s) {
                final selected = _session == s;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _session = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: s == 'Sabah' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryGreen : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.divider),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(s == 'Sabah' ? Icons.wb_sunny : Icons.nights_stay,
                            color: selected ? Colors.white : AppColors.textGrey, size: 20),
                        const SizedBox(width: 8),
                        Text(s, style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: selected ? Colors.white : AppColors.textGrey)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Sayılar
          _Card(
            title: 'Sağım Bilgileri',
            child: Column(children: [
              TextFormField(
                controller: _animalCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sağılan Hayvan Sayısı *',
                  prefixIcon: Icon(Icons.group, color: AppColors.primaryGreen, size: 20),
                  hintText: 'Örn: 50',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Toplam Süt Miktarı *',
                  prefixIcon: Icon(Icons.water_drop, color: AppColors.infoBlue, size: 20),
                  suffixText: 'Litre',
                  hintText: 'Örn: 500',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Tarih ve not
          _Card(
            title: 'Tarih & Not',
            child: Column(children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  prefixIcon: Icon(Icons.notes, color: AppColors.textGrey, size: 20),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

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
        child,
      ]),
    );
  }
}

// ─── BİREYSEL SAĞIM EKRANI ──────────────────────────────

class AddMilkingScreen extends StatefulWidget {
  const AddMilkingScreen({super.key});

  @override
  State<AddMilkingScreen> createState() => _AddMilkingScreenState();
}

class _AddMilkingScreenState extends State<AddMilkingScreen> {
  final _milkRepo = MilkingRepository();
  final _animalRepo = AnimalRepository();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  List<AnimalModel> _animals = [];
  AnimalModel? _selectedAnimal;
  String _session = 'Sabah';
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    setState(() => _isLoading = true);
    try {
      final animals = await _animalRepo.getByStatus('Sağımda');
      setState(() {
        _animals = animals;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hayvanlar yüklenemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_selectedAnimal == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen hayvan seçin')));
      return;
    }
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen miktar girin')));
      return;
    }
    setState(() => _isSaving = true);
    final model = MilkingModel(
      animalId: _selectedAnimal!.id!,
      animalEarTag: _selectedAnimal!.earTag,
      animalName: _selectedAnimal!.name ?? _selectedAnimal!.earTag,
      date: _date.toIso8601String().split('T').first,
      session: _session,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _milkRepo.insert(model);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sağım kaydedilemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bireysel Sağım'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  title: 'Sağım Öğünü',
                  child: Row(
                    children: ['Sabah', 'Akşam'].map((s) {
                      final selected = _session == s;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _session = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: s == 'Sabah' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primaryGreen : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selected ? AppColors.primaryGreen : AppColors.divider),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(
                                  s == 'Sabah' ? Icons.wb_sunny : Icons.nights_stay,
                                  color: selected ? Colors.white : AppColors.textGrey, size: 18),
                              const SizedBox(width: 8),
                              Text(s, style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : AppColors.textGrey)),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _Card(
                  title: 'Hayvan',
                  child: _animals.isEmpty
                      ? const Text(
                          'Sağımda hayvan bulunamadı. Önce hayvan durumunu "Sağımda" olarak güncelleyin.',
                          style: TextStyle(fontSize: 13, color: AppColors.textGrey))
                      : DropdownButtonFormField<AnimalModel>(
        initialValue: _selectedAnimal,
                          hint: const Text('Hayvan seçin'),
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.pets, color: AppColors.primaryGreen, size: 20)),
                          items: _animals
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.name ?? a.earTag} · ${a.breed}')))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedAnimal = v),
                        ),
                ),
                const SizedBox(height: 16),
                _Card(
                  title: 'Miktar & Tarih',
                  child: Column(children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Süt Miktarı (Litre)',
                        prefixIcon: Icon(Icons.water_drop, color: AppColors.infoBlue, size: 20),
                        suffixText: 'L',
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Not (isteğe bağlı)',
                        prefixIcon: Icon(Icons.notes, color: AppColors.textGrey, size: 20),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
