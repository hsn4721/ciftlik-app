import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/feed_model.dart';
import '../../data/repositories/feed_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/undo_snackbar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _repo = FeedRepository();

  List<FeedStockModel> _stocks = [];
  List<FeedPlanModel> _plans = [];
  List<FeedSessionModel> _todaySessions = [];
  List<FeedTransactionModel> _transactions = [];
  Map<int, int> _daysRemaining = {};
  double _dailyCost = 0;
  bool _loading = true;
  bool _autoMorning = false;
  bool _autoEvening = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAutoSettings().then((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAutoSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoMorning = prefs.getBool('feed_auto_morning') ?? false;
        _autoEvening = prefs.getBool('feed_auto_evening') ?? false;
      });
    }
  }

  Future<void> _saveAutoSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feed_auto_morning', _autoMorning);
    await prefs.setBool('feed_auto_evening', _autoEvening);
  }

  Future<void> _load({bool checkAuto = false}) async {
    setState(() => _loading = true);
    try {
      final stocks = await _repo.getAllStocks();
      final plans = await _repo.getPlans();
      final today = await _repo.getTodaySessions();
      final txns = await _repo.getRecentTransactions();
      final days = await _repo.getDaysRemaining();
      final cost = await _repo.getDailyPlanCost();
      if (mounted) {
        setState(() {
          _stocks = stocks;
          _plans = plans;
          _todaySessions = today;
          _transactions = txns;
          _daysRemaining = days;
          _dailyCost = cost;
          _loading = false;
        });
      }
      if (checkAuto) await _checkAutoApply();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yem verileri yüklenemedi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _checkAutoApply() async {
    if (!mounted) return;
    final hour = DateTime.now().hour;
    final morningDone = _todaySessions.any((s) => s.session == 'Sabah');
    final eveningDone = _todaySessions.any((s) => s.session == 'Akşam');
    final hasMorningPlan = _plans.any((p) => p.morningAmount > 0);
    final hasEveningPlan = _plans.any((p) => p.eveningAmount > 0);

    if (_autoMorning && !morningDone && hasMorningPlan && hour >= 5 && hour < 14) {
      final amounts = {for (final p in _plans.where((p) => p.morningAmount > 0)) p.stockId: p.morningAmount};
      final err = await _repo.applyFeedingWithAmounts('Sabah', amounts);
      if (mounted && err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Sabah yemi otomatik uygulandı'),
            ]),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
      }
    }

    if (_autoEvening && !eveningDone && hasEveningPlan && hour >= 16) {
      final amounts = {for (final p in _plans.where((p) => p.eveningAmount > 0)) p.stockId: p.eveningAmount};
      final err = await _repo.applyFeedingWithAmounts('Akşam', amounts);
      if (mounted && err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Akşam yemi otomatik uygulandı'),
            ]),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
      }
    }
  }

  Future<void> _applyFeeding(String session) async {
    final plans = _plans.where(
      (p) => session == 'Sabah' ? p.morningAmount > 0 : p.eveningAmount > 0,
    ).toList();
    if (plans.isEmpty) return;

    final result = await showModalBottomSheet<Map<int, double>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConfirmFeedingSheet(
        session: session,
        plans: plans,
        stocks: _stocks,
        autoEnabled: session == 'Sabah' ? _autoMorning : _autoEvening,
        onAutoChanged: (v) async {
          setState(() {
            if (session == 'Sabah') _autoMorning = v;
            else _autoEvening = v;
          });
          await _saveAutoSettings();
        },
      ),
    );

    if (result == null || !mounted) return;

    final error = await _repo.applyFeedingWithAmounts(session, result);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.errorRed),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$session yemi uygulandı'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      _load();
    }
  }

  Future<void> _deleteStock(FeedStockModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stok Sil'),
        content: Text('${s.name} stoğu silinecek. Devam edilsin mi?'),
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
      final backup = s;
      await _repo.deleteStock(s.id!);
      _load();
      if (mounted) {
        UndoSnackbar.show(
          context,
          message: '${backup.name} stoğu silindi',
          onUndo: () async {
            await _repo.insertStock(backup);
            _load();
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowCount = _stocks.where((s) => s.isLow).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yem Yönetimi'),
        actions: [
          if (lowCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('$lowCount Düşük', style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: AppColors.errorRed,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Stoklar'),
            Tab(icon: Icon(Icons.grass, size: 18), text: 'Yemleme'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Geçmiş'),
          ],
        ),
      ),
      floatingActionButton: Builder(builder: (_) {
        final u = AuthService.instance.currentUser;
        // Worker yemleme uygulayabilir (FAB'deki menüde sadece "Yemleme Uygula" gösterir);
        // stok ekleme owner+assistant. FAB'yi hep gösteriyoruz ama menü rol filtresi yapar.
        if (u != null && !u.canAddFeedStock && !u.canApplyFeeding) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: _showAddMenu,
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        );
      }),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.feed),
          _loading
              ? const SkeletonList(itemCount: 6, itemHeight: 84)
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _StocksTab(
                        stocks: _stocks,
                        daysRemaining: _daysRemaining,
                        onDelete: _deleteStock,
                        onRefresh: _load,
                      ),
                      _FeedingTab(
                        plans: _plans,
                        stocks: _stocks,
                        todaySessions: _todaySessions,
                        dailyCost: _dailyCost,
                        autoMorning: _autoMorning,
                        autoEvening: _autoEvening,
                        onApply: _applyFeeding,
                        onEditPlan: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => EditFeedPlanScreen(stocks: _stocks, plans: _plans),
                          ));
                          _load();
                        },
                      ),
                      _HistoryTab(transactions: _transactions, onRefresh: _load),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showAddMenu() async {
    final user = AuthService.instance.currentUser;
    // Personel yalnızca manuel çıkış yapabilir — yem tüketimini günceller.
    // Stok ekleme / alım girişi sadece Ana Sahip + Yardımcı'ya özel (maliyet vardır).
    final canManageStock = user?.canAddFeedStock ?? true;

    final result = await showModalBottomSheet<String>(
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
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ne eklemek istersiniz?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (canManageStock)
              ListTile(
                leading: _MenuIcon(Icons.inventory_2_outlined, AppColors.primaryGreen),
                title: const Text('Yeni Stok Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Yeni yem türü tanımla', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                onTap: () => Navigator.pop(context, 'stock'),
              ),
            if (canManageStock)
              ListTile(
                leading: _MenuIcon(Icons.add_shopping_cart, AppColors.infoBlue),
                title: const Text('Yem Satın Alımı', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Stoka yem girişi yap', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                onTap: () => Navigator.pop(context, 'buy'),
              ),
            ListTile(
              leading: _MenuIcon(Icons.remove_circle_outline, AppColors.errorRed),
              title: const Text('Manuel Çıkış', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Stoktan manuel düşüm yap', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
              onTap: () => Navigator.pop(context, 'out'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'stock') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFeedStockScreen()));
    } else if (result == 'buy') {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AddFeedTransactionScreen(isEntry: true)));
    } else if (result == 'out') {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AddFeedTransactionScreen(isEntry: false)));
    }
    _load();
  }
}

// ─── Stoklar Tab ─────────────────────────────────────────────────────────────

class _StocksTab extends StatelessWidget {
  final List<FeedStockModel> stocks;
  final Map<int, int> daysRemaining;
  final Function(FeedStockModel) onDelete;
  final VoidCallback onRefresh;
  const _StocksTab({required this.stocks, required this.daysRemaining, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Stok Yok',
        subtitle: 'Henüz yem stoğu eklenmemiş.\nSağ üstteki + butonuna basarak ekleyebilirsiniz.',
      );
    }
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    final moneyFmt = NumberFormat('#,##0.00', 'tr_TR');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: stocks.length,
      itemBuilder: (_, i) {
        final s = stocks[i];
        final isLow = s.isLow;
        final days = daysRemaining[s.id];
        Color statusColor = AppColors.primaryGreen;
        if (isLow) statusColor = AppColors.errorRed;
        else if (days != null && days < 7) statusColor = AppColors.gold;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: statusColor, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.grass, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        if (isLow)
                          _Badge('Düşük Stok', AppColors.errorRed)
                        else if (days != null && days < 7)
                          _Badge('$days Gün Kaldı', AppColors.gold),
                      ]),
                      const SizedBox(height: 4),
                      Text('${s.type}', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _InfoChip(Icons.scale_outlined, '${fmt.format(s.quantity)} ${s.unit}', AppColors.primaryGreen),
                          if (s.unitPrice != null &&
                              (AuthService.instance.currentUser?.canSeeFeedCost ?? true))
                            _InfoChip(Icons.attach_money, '${moneyFmt.format(s.unitPrice!)} ₺/${s.unit}', AppColors.infoBlue),
                          if (days != null && days >= 7)
                            _InfoChip(Icons.calendar_today_outlined, '$days gün', const Color(0xFF6B4EFF)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) { if (v == 'delete') onDelete(s); },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8), Text('Sil'),
                    ])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Günlük Yemleme Tab ──────────────────────────────────────────────────────

class _FeedingTab extends StatelessWidget {
  final List<FeedPlanModel> plans;
  final List<FeedStockModel> stocks;
  final List<FeedSessionModel> todaySessions;
  final double dailyCost;
  final bool autoMorning;
  final bool autoEvening;
  final Function(String) onApply;
  final VoidCallback onEditPlan;

  const _FeedingTab({
    required this.plans,
    required this.stocks,
    required this.todaySessions,
    required this.dailyCost,
    required this.autoMorning,
    required this.autoEvening,
    required this.onApply,
    required this.onEditPlan,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(today);
    final morningDone = todaySessions.any((s) => s.session == 'Sabah');
    final eveningDone = todaySessions.any((s) => s.session == 'Akşam');
    final hasPlan = plans.any((p) => p.morningAmount > 0 || p.eveningAmount > 0);
    final moneyFmt = NumberFormat('#,##0.00', 'tr_TR');
    final fmt = NumberFormat('#,##0.##', 'tr_TR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.today, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bugün', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const Spacer(),
            if (dailyCost > 0 && (AuthService.instance.currentUser?.canSeeFeedCost ?? true))
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Günlük Maliyet', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('₺${moneyFmt.format(dailyCost)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
          ]),
        ),
        const SizedBox(height: 16),

        if (!hasPlan) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 36),
              const SizedBox(height: 8),
              const Text('Yemleme Planı Yok', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Sabah/akşam yem miktarlarını tanımlamak için plan oluşturun.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onEditPlan,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Yemleme Planı Oluştur'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              ),
            ]),
          ),
        ] else ...[
          _FeedingCard(
            session: 'Sabah',
            icon: Icons.wb_sunny,
            color: const Color(0xFFF57F17),
            isDone: morningDone,
            isAuto: autoMorning,
            plans: plans.where((p) => p.morningAmount > 0).toList(),
            onApply: () => onApply('Sabah'),
            fmt: fmt,
          ),
          const SizedBox(height: 12),
          _FeedingCard(
            session: 'Akşam',
            icon: Icons.nights_stay,
            color: const Color(0xFF1565C0),
            isDone: eveningDone,
            isAuto: autoEvening,
            plans: plans.where((p) => p.eveningAmount > 0).toList(),
            onApply: () => onApply('Akşam'),
            fmt: fmt,
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.list_alt, color: AppColors.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  const Text('Günlük Yem Planı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onEditPlan,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Düzenle'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen, padding: EdgeInsets.zero),
                  ),
                ]),
                const Divider(),
                ...plans.where((p) => p.dailyAmount > 0).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.grass, color: AppColors.primaryGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.stockName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    if (p.morningAmount > 0)
                      _SessionBadge('S: ${fmt.format(p.morningAmount)} ${p.unit}', const Color(0xFFF57F17)),
                    const SizedBox(width: 6),
                    if (p.eveningAmount > 0)
                      _SessionBadge('A: ${fmt.format(p.eveningAmount)} ${p.unit}', const Color(0xFF1565C0)),
                  ]),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedingCard extends StatelessWidget {
  final String session;
  final IconData icon;
  final Color color;
  final bool isDone;
  final bool isAuto;
  final List<FeedPlanModel> plans;
  final VoidCallback onApply;
  final NumberFormat fmt;

  const _FeedingCard({
    required this.session,
    required this.icon,
    required this.color,
    required this.isDone,
    required this.isAuto,
    required this.plans,
    required this.onApply,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.primaryGreen : color.withValues(alpha: 0.3),
          width: isDone ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDone ? AppColors.primaryGreen : color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(isDone ? Icons.check_circle : icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text('$session Yemi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Verildi ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                )
              else
                ElevatedButton(
                  onPressed: plans.isEmpty ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              if (isAuto)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: plans.isEmpty ? null : onApply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.autorenew, color: Colors.white, size: 13),
                        SizedBox(width: 3),
                        Text('Oto', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          if (plans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Bu oturum için plan yok', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            )
          else
            ...plans.map((p) {
              final amount = session == 'Sabah' ? p.morningAmount : p.eveningAmount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.grass, color: AppColors.primaryGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.stockName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('${fmt.format(amount)} ${p.unit}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                ]),
              );
            }),
          if (plans.isNotEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Yemleme Onay & Düzenleme Sheet ─────────────────────────────────────────

class _ConfirmFeedingSheet extends StatefulWidget {
  final String session;
  final List<FeedPlanModel> plans;
  final List<FeedStockModel> stocks;
  final bool autoEnabled;
  final Function(bool) onAutoChanged;

  const _ConfirmFeedingSheet({
    required this.session,
    required this.plans,
    required this.stocks,
    required this.autoEnabled,
    required this.onAutoChanged,
  });

  @override
  State<_ConfirmFeedingSheet> createState() => _ConfirmFeedingSheetState();
}

class _ConfirmFeedingSheetState extends State<_ConfirmFeedingSheet> {
  late Map<int, TextEditingController> _controllers;
  late bool _auto;

  @override
  void initState() {
    super.initState();
    _auto = widget.autoEnabled;
    _controllers = {};
    for (final plan in widget.plans) {
      final defaultAmt = widget.session == 'Sabah' ? plan.morningAmount : plan.eveningAmount;
      _controllers[plan.stockId] = TextEditingController(
        text: defaultAmt > 0 ? defaultAmt.toString() : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  double _totalCost() {
    double total = 0;
    for (final plan in widget.plans) {
      final stock = widget.stocks.where((s) => s.id == plan.stockId).firstOrNull;
      if (stock?.unitPrice == null) continue;
      final amt = double.tryParse(_controllers[plan.stockId]?.text.replaceAll(',', '.') ?? '') ?? 0;
      total += amt * stock!.unitPrice!;
    }
    return total;
  }

  Map<int, double> _buildAmounts() {
    final result = <int, double>{};
    for (final plan in widget.plans) {
      final amt = double.tryParse(_controllers[plan.stockId]?.text.replaceAll(',', '.') ?? '') ?? 0;
      if (amt > 0) result[plan.stockId] = amt;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isAm = widget.session == 'Sabah';
    final color = isAm ? const Color(0xFFF57F17) : const Color(0xFF1565C0);
    final icon = isAm ? Icons.wb_sunny : Icons.nights_stay;
    final moneyFmt = NumberFormat('#,##0.00', 'tr_TR');
    final totalCost = _totalCost();
    final hasCost = totalCost > 0;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + 16;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── başlık ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${widget.session} Yemi Onayı',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const Text('Miktarları düzenleyip onaylayın',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            ]),
          ),

          // ── içerik (kaydırılabilir) ──────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // yem listesi
                  ...widget.plans.map((plan) {
                    final stock = widget.stocks.where((s) => s.id == plan.stockId).firstOrNull;
                    final canSeeCost = AuthService.instance.currentUser?.canSeeFeedCost ?? true;
                    final hasPrice = stock?.unitPrice != null && canSeeCost;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                      ),
                      child: Row(children: [
                        const Icon(Icons.grass, color: AppColors.primaryGreen, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(plan.stockName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            if (hasPrice)
                              Text('₺${moneyFmt.format(stock!.unitPrice!)}/${plan.unit}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ]),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _controllers[plan.stockId],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              suffixText: plan.unit,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: color.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: color.withValues(alpha: 0.5))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: color, width: 2)),
                            ),
                          ),
                        ),
                      ]),
                    );
                  }),

                  // maliyet özeti — personel görmez
                  if (hasCost && (AuthService.instance.currentUser?.canSeeFeedCost ?? true)) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        const Text('Maliyet:', style: TextStyle(fontSize: 13, color: AppColors.primaryGreen)),
                        const Spacer(),
                        Text('₺${moneyFmt.format(totalCost)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryGreen)),
                        const SizedBox(width: 6),
                        const Text('Finansa yazılacak', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // otomatik switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.autorenew, color: AppColors.infoBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${widget.session} Otomatik Uygula',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const Text('Her gün onay beklemeden otomatik uygulanır',
                              style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                        ]),
                      ),
                      Switch(
          value: _auto,
          activeThumbColor: AppColors.primaryGreen,
                        onChanged: (v) {
                          setState(() => _auto = v);
                          widget.onAutoChanged(v);
                        },
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // butonlar
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final amounts = _buildAmounts();
                          if (amounts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('En az bir yem miktarı giriniz'),
                                  backgroundColor: AppColors.errorRed),
                            );
                            return;
                          }
                          Navigator.pop(context, amounts);
                        },
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                        label: Text('${widget.session} Yemini Uygula',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Geçmiş Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<FeedTransactionModel> transactions;
  final VoidCallback onRefresh;
  const _HistoryTab({required this.transactions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const EmptyState(icon: Icons.history, title: 'Kayıt Yok', subtitle: 'Henüz yem işlemi bulunmuyor.');
    }
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    final moneyFmt = NumberFormat('#,##0.00', 'tr_TR');

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        itemCount: transactions.length,
        itemBuilder: (_, i) {
          final t = transactions[i];
          Color color;
          IconData icon;
          if (t.transactionType == 'Sabah Yemi') { color = const Color(0xFFF57F17); icon = Icons.wb_sunny; }
          else if (t.transactionType == 'Akşam Yemi') { color = const Color(0xFF1565C0); icon = Icons.nights_stay; }
          else if (t.isEntry) { color = AppColors.primaryGreen; icon = Icons.add_circle_outline; }
          else { color = AppColors.errorRed; icon = Icons.remove_circle_outline; }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: color, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3)],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 18),
              ),
              title: Text(t.stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${t.date} • ${t.transactionType}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${t.isEntry ? '+' : '-'}${fmt.format(t.quantity)} ${t.unit}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13),
                  ),
                  if (t.totalCost != null &&
                      (AuthService.instance.currentUser?.canSeeFeedCost ?? true))
                    Text('₺${moneyFmt.format(t.totalCost!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Yemleme Planı Düzenleme ─────────────────────────────────────────────────

class EditFeedPlanScreen extends StatefulWidget {
  final List<FeedStockModel> stocks;
  final List<FeedPlanModel> plans;
  const EditFeedPlanScreen({super.key, required this.stocks, required this.plans});

  @override
  State<EditFeedPlanScreen> createState() => _EditFeedPlanScreenState();
}

class _EditFeedPlanScreenState extends State<EditFeedPlanScreen> {
  final _repo = FeedRepository();
  final Map<int, TextEditingController> _morningCtrl = {};
  final Map<int, TextEditingController> _eveningCtrl = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final stock in widget.stocks) {
      final plan = widget.plans.where((p) => p.stockId == stock.id).firstOrNull;
      _morningCtrl[stock.id!] = TextEditingController(
        text: plan != null && plan.morningAmount > 0 ? plan.morningAmount.toString() : '');
      _eveningCtrl[stock.id!] = TextEditingController(
        text: plan != null && plan.eveningAmount > 0 ? plan.eveningAmount.toString() : '');
    }
  }

  @override
  void dispose() {
    for (final c in _morningCtrl.values) c.dispose();
    for (final c in _eveningCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final stock in widget.stocks) {
        final id = stock.id;
        if (id == null) continue;
        final morning = double.tryParse(_morningCtrl[id]?.text.replaceAll(',', '.') ?? '') ?? 0;
        final evening = double.tryParse(_eveningCtrl[id]?.text.replaceAll(',', '.') ?? '') ?? 0;
        if (morning > 0 || evening > 0) {
          await _repo.savePlan(FeedPlanModel(
            stockId: id,
            stockName: stock.name,
            unit: stock.unit,
            morningAmount: morning,
            eveningAmount: evening,
            updatedAt: DateTime.now().toIso8601String(),
          ));
        } else {
          await _repo.deletePlan(id);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yemleme Planı'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: widget.stocks.isEmpty
          ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Stok Yok', subtitle: 'Önce yem stoğu ekleyin.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Her yem için sabah ve akşam verilecek miktarı girin. Boş bırakılan oturum planlanmaz.',
                      style: TextStyle(fontSize: 12, color: AppColors.primaryGreen),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
                ...widget.stocks.map((stock) => _PlanStockCard(
                  stock: stock,
                  morningCtrl: _morningCtrl[stock.id!]!,
                  eveningCtrl: _eveningCtrl[stock.id!]!,
                )),
              ],
            ),
    );
  }
}

class _PlanStockCard extends StatelessWidget {
  final FeedStockModel stock;
  final TextEditingController morningCtrl;
  final TextEditingController eveningCtrl;
  const _PlanStockCard({required this.stock, required this.morningCtrl, required this.eveningCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.grass, color: AppColors.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(stock.type, style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _PlanField(
                  ctrl: morningCtrl,
                  label: 'Sabah',
                  icon: Icons.wb_sunny,
                  color: const Color(0xFFF57F17),
                  unit: stock.unit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanField(
                  ctrl: eveningCtrl,
                  label: 'Akşam',
                  icon: Icons.nights_stay,
                  color: const Color(0xFF1565C0),
                  unit: stock.unit,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PlanField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Color color;
  final String unit;
  const _PlanField({required this.ctrl, required this.label, required this.icon, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            hintText: '0',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color)),
          ),
        ),
      ],
    );
  }
}

// ─── Stok Ekleme ─────────────────────────────────────────────────────────────

class AddFeedStockScreen extends StatefulWidget {
  const AddFeedStockScreen({super.key});

  @override
  State<AddFeedStockScreen> createState() => _AddFeedStockScreenState();
}

class _AddFeedStockScreenState extends State<AddFeedStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FeedRepository();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _minQtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedPreset;
  String _type = AppConstants.feedTypes.first;
  String _unit = AppConstants.feedUnits.first;
  bool _saving = false;
  bool _isCustomName = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose();
    _minQtyCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _onPresetSelected(String? preset) {
    if (preset == null) return;
    if (preset == 'Diğer (Manuel Gir)') {
      setState(() { _selectedPreset = preset; _isCustomName = true; _nameCtrl.clear(); });
      return;
    }
    final match = AppConstants.feedPresets.where((p) => p['name'] == preset).firstOrNull;
    setState(() {
      _selectedPreset = preset;
      _isCustomName = false;
      _nameCtrl.text = preset;
      if (match != null) _type = match['type']!;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yem adı giriniz'), backgroundColor: AppColors.errorRed));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final model = FeedStockModel(
      name: name,
      type: _type,
      quantity: qty,
      unit: _unit,
      unitPrice: _priceCtrl.text.isEmpty ? null : double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
      minQuantity: _minQtyCtrl.text.isEmpty ? null : double.tryParse(_minQtyCtrl.text.replaceAll(',', '.')),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _repo.insertStock(model);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name stoğu eklendi${qty > 0 ? " ($qty $_unit)" : ""}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final presetNames = [
      ...AppConstants.feedPresets.map((p) => p['name']!).where((n) => n != 'Diğer'),
      'Diğer (Manuel Gir)',
    ];
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final totalCost = price != null && qty > 0 ? qty * price : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yem Stoğu Ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bilgi kutusu
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primaryGreen, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Aynı isimde stok varsa mevcut miktarın üstüne eklenir.',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryGreen),
                )),
              ]),
            ),

            _FormCard(title: 'Yem Seçimi', children: [
              // Hazır liste
              DropdownButtonFormField<String>(
        initialValue: _selectedPreset,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Yem Adı *',
                  prefixIcon: Icon(Icons.grass, color: AppColors.primaryGreen, size: 20),
                  hintText: 'Listeden seçin',
                ),
                items: presetNames.map((name) {
                  final match = AppConstants.feedPresets.where((p) => p['name'] == name).firstOrNull;
                  return DropdownMenuItem(
                    value: name,
                    child: Row(children: [
                      Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                      if (match != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(match['type']!, style: const TextStyle(fontSize: 10, color: AppColors.primaryGreen)),
                        ),
                    ]),
                  );
                }).toList(),
                onChanged: _onPresetSelected,
              ),

              // Manuel giriş (Diğer seçilince)
              if (_isCustomName) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Özel Yem Adı *',
                    prefixIcon: Icon(Icons.edit, color: AppColors.primaryGreen, size: 20),
                  ),
                  validator: (v) => _isCustomName && (v == null || v.isEmpty) ? 'Yem adı giriniz' : null,
                ),
              ],

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
        initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Yem Kategorisi',
                  prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryGreen, size: 20),
                ),
                items: AppConstants.feedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
            ]),

            const SizedBox(height: 12),
            _FormCard(title: 'Miktar & Fiyat', children: [
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Stok Miktarı',
                      prefixIcon: Icon(Icons.scale_outlined, color: AppColors.primaryGreen, size: 20),
                      hintText: '0',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
        initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Birim'),
                    items: AppConstants.feedUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Alış Fiyatı (₺/$_unit)',
                  prefixIcon: const Icon(Icons.attach_money, color: AppColors.primaryGreen, size: 20),
                  hintText: '0.00',
                  helperText: qty > 0 ? 'Finansa otomatik gider kaydı için zorunlu' : null,
                  helperStyle: const TextStyle(color: AppColors.infoBlue, fontSize: 11),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final q = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
                  if (q > 0 && (v == null || v.trim().isEmpty)) {
                    return 'Miktar girildiyse alış fiyatı zorunludur';
                  }
                  return null;
                },
              ),
              if (totalCost != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Text('Toplam: ₺${NumberFormat('#,##0.00', 'tr_TR').format(totalCost)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen, fontSize: 13)),
                    const Spacer(),
                    const Text('Finansa yazılacak', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _minQtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Minimum Uyarı Seviyesi ($_unit)',
                  prefixIcon: const Icon(Icons.warning_amber_outlined, color: AppColors.gold, size: 20),
                  hintText: 'Bu seviyenin altına düşünce uyar',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notlar',
                  prefixIcon: Icon(Icons.notes, color: AppColors.primaryGreen, size: 20),
                ),
              ),
            ]),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving || _selectedPreset == null ? null : _save,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _qtyCtrl.text.isEmpty ? 'Stok Tanımla' : 'Stoğu Kaydet (${fmt.format(qty)} $_unit)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ]),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Satın Alım / Manuel Çıkış ───────────────────────────────────────────────

class AddFeedTransactionScreen extends StatefulWidget {
  final bool isEntry;
  const AddFeedTransactionScreen({super.key, required this.isEntry});

  @override
  State<AddFeedTransactionScreen> createState() => _AddFeedTransactionScreenState();
}

class _AddFeedTransactionScreenState extends State<AddFeedTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FeedRepository();

  List<FeedStockModel> _stocks = [];
  int? _selectedStockId;
  FeedStockModel? get _selectedStock =>
      _stocks.where((s) => s.id == _selectedStockId).firstOrNull;

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _loadingStocks = true;

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    final stocks = await _repo.getAllStocks();
    if (mounted) setState(() { _stocks = stocks; _loadingStocks = false; });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose(); _priceCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir stok seçin'), backgroundColor: AppColors.errorRed));
      return;
    }
    final stock = _selectedStock!;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    if (!widget.isEntry && qty > stock.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yetersiz stok! Mevcut: ${stock.quantity} ${stock.unit}'),
          backgroundColor: AppColors.errorRed));
      return;
    }
    setState(() => _saving = true);
    final txn = FeedTransactionModel(
      stockId: stock.id!,
      stockName: stock.name,
      transactionType: widget.isEntry ? 'Giriş' : 'Çıkış',
      quantity: qty,
      unit: stock.unit,
      unitPrice: _priceCtrl.text.isEmpty ? null : double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
      date: DateFormat('yyyy-MM-dd').format(_date),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    try {
      await _repo.insertTransaction(txn);
      if (!mounted) return;
      final newQty = widget.isEntry ? stock.quantity + qty : stock.quantity - qty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${stock.name}: ${widget.isEntry ? "+" : "-"}$qty ${stock.unit} → Yeni stok: ${newQty.clamp(0, double.infinity)} ${stock.unit}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isEntry ? AppColors.primaryGreen : AppColors.errorRed;
    final stock = _selectedStock;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final totalCost = widget.isEntry && price != null && qty > 0 ? qty * price : null;
    final afterQty = stock != null && qty > 0
        ? (widget.isEntry ? stock.quantity + qty : (stock.quantity - qty).clamp(0, double.infinity))
        : null;
    final fmt = NumberFormat('#,##0.##', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEntry ? 'Yem Satın Alımı' : 'Manuel Stok Çıkışı'),
        backgroundColor: color,
      ),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _stocks.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textGrey),
                  const SizedBox(height: 12),
                  const Text('Stok bulunamadı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Önce yem stoğu tanımlayın', style: TextStyle(color: AppColors.textGrey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFeedStockScreen()));
                      _loadStocks();
                    },
                    child: const Text('Stok Ekle'),
                  ),
                ]))
              : Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormCard(title: 'Stok Seçimi', children: [
              // Stok kartları — dokunarak seç
              const Text('Hangi yem?', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stocks.map((s) {
                  final isSelected = s.id == _selectedStockId;
                  final isLow = s.isLow;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedStockId = s.id;
                      // Alış fiyatını otomatik doldur
                      if (widget.isEntry && s.unitPrice != null && _priceCtrl.text.isEmpty) {
                        _priceCtrl.text = s.unitPrice!.toString();
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : (isLow ? AppColors.errorRed : Colors.grey.shade300),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(s.name, style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text('${fmt.format(s.quantity)} ${s.unit}',
                          style: TextStyle(fontSize: 11,
                            color: isSelected ? Colors.white70 : (isLow ? AppColors.errorRed : AppColors.textGrey))),
                      ]),
                    ),
                  );
                }).toList(),
              ),

              // Seçili stok detayı
              if (stock != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stock.name, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                      Text('${stock.type} • Mevcut: ${fmt.format(stock.quantity)} ${stock.unit}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ])),
                    if (afterQty != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Sonrası', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                        Text('${fmt.format(afterQty)} ${stock.unit}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
                      ]),
                  ]),
                ),
              ],
            ]),

            const SizedBox(height: 12),
            _FormCard(title: widget.isEntry ? 'Alım Bilgileri' : 'Çıkış Bilgileri', children: [
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Miktar *',
                  prefixIcon: const Icon(Icons.scale_outlined, color: AppColors.primaryGreen, size: 20),
                  suffixText: stock?.unit ?? '',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Miktar giriniz';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              if (widget.isEntry) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Birim Fiyat (₺/${stock?.unit ?? ''})',
                    prefixIcon: const Icon(Icons.attach_money, color: AppColors.primaryGreen, size: 20),
                    hintText: 'Maliyet hesabı için',
                  ),
                  validator: widget.isEntry ? (v) => (v == null || v.trim().isEmpty) ? 'Satın alım fiyatı zorunludur' : null : null,
                  onChanged: (_) => setState(() {}),
                ),
                if (totalCost != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.receipt_long, size: 16, color: AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      Text('Toplam Tutar: ₺${NumberFormat('#,##0.00', 'tr_TR').format(totalCost)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen, fontSize: 13)),
                    ]),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen)),
                      child: child!));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tarih',
                    prefixIcon: Icon(Icons.calendar_today, color: AppColors.primaryGreen, size: 20),
                  ),
                  child: Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notlar',
                  prefixIcon: Icon(Icons.notes, color: AppColors.primaryGreen, size: 20),
                ),
              ),
            ]),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(widget.isEntry ? 'Satın Alımı Kaydet' : 'Çıkışı Kaydet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yardımcı Widget'lar ─────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SessionBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SessionBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MenuIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color),
    );
  }
}
