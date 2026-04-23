import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/finance_model.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/empty_state.dart';

// ─── Category helpers ─────────────────────────────────────────────────────────

IconData _catIcon(String cat) {
  switch (cat) {
    case AppConstants.incomeMilk:       return Icons.water_drop;
    case AppConstants.incomeCalf:       return Icons.pets;
    case AppConstants.incomeAnimal:     return Icons.storefront;
    case AppConstants.incomeManure:     return Icons.compost;
    case AppConstants.incomeSubsidy:    return Icons.account_balance;
    case AppConstants.incomeOther:      return Icons.add_circle_outline;
    case AppConstants.expenseFeed:      return Icons.grass;
    case AppConstants.expenseMedicine:  return Icons.medication;
    case AppConstants.expenseVet:       return Icons.medical_services;
    case AppConstants.expenseAnimal:    return Icons.agriculture;
    case AppConstants.expenseEnergy:    return Icons.bolt;
    case AppConstants.expenseLabor:     return Icons.people;
    case AppConstants.expenseEquipment: return Icons.build;
    case AppConstants.expenseOther:     return Icons.more_horiz;
    default:                            return Icons.attach_money;
  }
}

Color _catColor(String cat) {
  if (AppConstants.incomeCategories.contains(cat)) return const Color(0xFF2E7D32);
  switch (cat) {
    case AppConstants.expenseFeed:      return const Color(0xFF795548);
    case AppConstants.expenseMedicine:  return const Color(0xFFE91E63);
    case AppConstants.expenseVet:       return const Color(0xFF9C27B0);
    case AppConstants.expenseAnimal:    return const Color(0xFFFF5722);
    case AppConstants.expenseEnergy:    return const Color(0xFFFFA000);
    case AppConstants.expenseLabor:     return const Color(0xFF3F51B5);
    case AppConstants.expenseEquipment: return const Color(0xFF607D8B);
    default:                            return const Color(0xFF9E9E9E);
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _repo = FinanceRepository();

  // Günlük
  DateTime _day = DateTime.now();
  List<FinanceModel> _daily = [];
  bool _loadingDaily = true;

  // Aylık
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  List<FinanceModel> _monthly = [];      // period='monthly'
  List<FinanceModel> _milkMonth = [];    // period='daily', Süt Satışı — ay toplamı için
  Map<String, double> _summary = {'income': 0, 'expense': 0, 'profit': 0};
  bool _loadingMonthly = true;

  // Kayıtlar
  List<FinanceModel> _all = [];
  String _filter = 'Tümü';
  bool _loadingAll = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await Future.wait([_loadDaily(), _loadMonthly(), _loadAllRecords()]);
  }

  Future<void> _loadDaily() async {
    setState(() => _loadingDaily = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(_day);
      final records = await _repo.getByDate(date);
      if (mounted) setState(() { _daily = records; _loadingDaily = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDaily = false);
    }
  }

  Future<void> _loadMonthly() async {
    setState(() => _loadingMonthly = true);
    try {
      final results = await Future.wait([
        _repo.getMonthlyOnly(_year, _month),
        _repo.getMilkSalesByMonth(_year, _month),
        _repo.getMonthSummaryMonthlyOnly(_year, _month),
      ]);
      if (mounted) setState(() {
        _monthly    = results[0] as List<FinanceModel>;
        _milkMonth  = results[1] as List<FinanceModel>;
        _summary    = results[2] as Map<String, double>;
        _loadingMonthly = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _loadAllRecords() async {
    setState(() => _loadingAll = true);
    try {
      final records = await _repo.getAll();
      if (mounted) setState(() { _all = records; _loadingAll = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _prevDay() {
    setState(() => _day = _day.subtract(const Duration(days: 1)));
    _loadDaily();
  }

  void _nextDay() {
    if (_isToday) return;
    setState(() => _day = _day.add(const Duration(days: 1)));
    _loadDaily();
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; }
      else _month--;
    });
    _loadMonthly();
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_month == 12) { _month = 1; _year++; }
      else _month++;
    });
    _loadMonthly();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  Future<void> _delete(FinanceModel f) async {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('${f.category} — ₺${fmt.format(f.amount)} silinsin mi?'),
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
      await _repo.delete(f.id!);
      _reload();
    }
  }

  Future<void> _exportExcel() async {
    final monthLabel = DateFormat('MMMM_yyyy', 'tr_TR').format(DateTime(_year, _month));
    final monthLabelDisplay = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_year, _month));
    final numFmt = NumberFormat('#,##0.00', 'tr_TR');
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());

    final excel = Excel.createExcel();

    // ── Sheet 1: Aylık Özet ───────────────────────────────────────────────────
    final sheetOzet = excel['Aylık Özet'];
    excel.setDefaultSheet('Aylık Özet');

    void addRow(Sheet s, List<String> cells, {bool bold = false}) {
      s.appendRow(cells.map<CellValue>((c) => TextCellValue(c)).toList());
      if (bold) {
        final rowIdx = s.maxRows - 1;
        for (var col = 0; col < cells.length; col++) {
          s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx))
            .cellStyle = CellStyle(bold: true);
        }
      }
    }

    // Başlık
    sheetOzet.appendRow([TextCellValue('ÇiftlikPRO Finans Raporu'), TextCellValue(''), TextCellValue('')]);
    sheetOzet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(bold: true, fontSize: 14);
    sheetOzet.appendRow([TextCellValue('Dönem: $monthLabelDisplay'), TextCellValue(''), TextCellValue('')]);
    sheetOzet.appendRow([TextCellValue('Rapor tarihi: $today'), TextCellValue(''), TextCellValue('')]);
    sheetOzet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('')]);

    // Gelir kategorileri
    addRow(sheetOzet, ['GELİRLER', 'Detay', 'Tutar (₺)'], bold: true);

    // Süt satışı (günlük kayıtların aylık toplamı)
    final milkTotal  = _milkMonth.fold(0.0, (s, r) => s + r.amount);
    final milkLiters = _milkMonth.fold(0.0, (s, r) {
      final m = RegExp(r'([\d.]+)\s*L').firstMatch(r.description ?? '');
      return s + (m != null ? double.tryParse(m.group(1) ?? '') ?? 0 : 0);
    });
    double totalIncome = milkTotal;
    if (milkTotal > 0) {
      sheetOzet.appendRow([
        TextCellValue('Süt Satışı'),
        TextCellValue('${_milkMonth.length} günlük${milkLiters > 0 ? ' · ${milkLiters.toStringAsFixed(1)} L' : ''}'),
        TextCellValue(numFmt.format(milkTotal)),
      ]);
    }

    // Diğer monthly gelir kategorileri
    final incomeByCat = <String, double>{};
    final incomeCount = <String, int>{};
    for (final r in _monthly.where((r) => r.isIncome)) {
      incomeByCat[r.category] = (incomeByCat[r.category] ?? 0) + r.amount;
      incomeCount[r.category] = (incomeCount[r.category] ?? 0) + 1;
    }
    final sortedIncome = incomeByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedIncome) {
      sheetOzet.appendRow([
        TextCellValue(e.key),
        TextCellValue('${incomeCount[e.key]} kayıt'),
        TextCellValue(numFmt.format(e.value)),
      ]);
      totalIncome += e.value;
    }
    addRow(sheetOzet, ['TOPLAM GELİR', '', numFmt.format(totalIncome)], bold: true);
    sheetOzet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('')]);

    // Gider kategorileri
    addRow(sheetOzet, ['GİDERLER', 'Kayıt Sayısı', 'Tutar (₺)'], bold: true);
    final expenseByCat = <String, double>{};
    final expenseCount = <String, int>{};
    for (final r in _monthly.where((r) => !r.isIncome)) {
      expenseByCat[r.category] = (expenseByCat[r.category] ?? 0) + r.amount;
      expenseCount[r.category] = (expenseCount[r.category] ?? 0) + 1;
    }
    final sortedExpense = expenseByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    double totalExpense = 0;
    for (final e in sortedExpense) {
      sheetOzet.appendRow([
        TextCellValue(e.key),
        TextCellValue('${expenseCount[e.key]}'),
        TextCellValue(numFmt.format(e.value)),
      ]);
      totalExpense += e.value;
    }
    addRow(sheetOzet, ['TOPLAM GİDER', '', numFmt.format(totalExpense)], bold: true);
    sheetOzet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('')]);

    final net = totalIncome - totalExpense;
    addRow(sheetOzet, ['NET KÂR / ZARAR', '', numFmt.format(net)], bold: true);

    // Kolon genişlikleri
    sheetOzet.setColumnWidth(0, 28);
    sheetOzet.setColumnWidth(1, 14);
    sheetOzet.setColumnWidth(2, 16);

    // ── Sheet 2: Tüm Kayıtlar ─────────────────────────────────────────────────
    final sheetAll = excel['Tüm Kayıtlar'];
    addRow(sheetAll, ['Tarih', 'Tür', 'Kategori', 'Tutar (₺)', 'Açıklama', 'Periyot', 'Oluşturma'], bold: true);

    final sorted = List<FinanceModel>.from(_all)
      ..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });
    for (final r in sorted) {
      sheetAll.appendRow([
        TextCellValue(DateFormat('dd.MM.yyyy').format(DateTime.parse(r.date))),
        TextCellValue(r.type),
        TextCellValue(r.category),
        TextCellValue(numFmt.format(r.amount)),
        TextCellValue(r.description ?? ''),
        TextCellValue(r.period == 'daily' ? 'Günlük' : 'Aylık'),
        TextCellValue(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(r.createdAt))),
      ]);
    }
    sheetAll.setColumnWidth(0, 12);
    sheetAll.setColumnWidth(1, 8);
    sheetAll.setColumnWidth(2, 20);
    sheetAll.setColumnWidth(3, 14);
    sheetAll.setColumnWidth(4, 36);
    sheetAll.setColumnWidth(5, 10);
    sheetAll.setColumnWidth(6, 18);

    // ── Dosyaya kaydet & paylaş ───────────────────────────────────────────────
    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/CiftlikPRO_Finans_$monthLabel.xlsx');
    await file.writeAsBytes(bytes);

    if (mounted) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'ÇiftlikPRO Finans Raporu — $monthLabelDisplay',
      );
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddRecordSheet(onSaved: _reload, initialDate: _day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelir & Gider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _all.isEmpty ? null : _exportExcel,
            tooltip: 'Excel\'e Aktar',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddSheet,
            tooltip: 'Kayıt Ekle',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.today, size: 18), text: 'Günlük'),
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Aylık'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Kayıtlar'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.finance),
          TabBarView(
            controller: _tab,
            children: [
              _DailyTab(
                day: _day,
                records: _daily,
                loading: _loadingDaily,
                isToday: _isToday,
                onPrevDay: _prevDay,
                onNextDay: _nextDay,
                onDelete: _delete,
                onAdd: _showAddSheet,
                onRefresh: _reload,
              ),
              _MonthlyTab(
                year: _year,
                month: _month,
                records: _monthly,
                milkSales: _milkMonth,
                summary: _summary,
                loading: _loadingMonthly,
                isCurrentMonth: _isCurrentMonth,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
                onRefresh: _reload,
              ),
              _RecordsTab(
                records: _all,
                filter: _filter,
                loading: _loadingAll,
                onFilterChanged: (f) => setState(() => _filter = f),
                onDelete: _delete,
                onRefresh: _reload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Daily Tab ────────────────────────────────────────────────────────────────

class _DailyTab extends StatelessWidget {
  final DateTime day;
  final List<FinanceModel> records;
  final bool loading;
  final bool isToday;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final Function(FinanceModel) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  const _DailyTab({
    required this.day,
    required this.records,
    required this.loading,
    required this.isToday,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final dayLabel = isToday
        ? 'Bugün — ${DateFormat('d MMMM yyyy', 'tr_TR').format(day)}'
        : DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(day);

    final income = records.where((r) => r.isIncome).fold(0.0, (s, r) => s + r.amount);
    final expense = records.where((r) => !r.isIncome).fold(0.0, (s, r) => s + r.amount);
    final net = income - expense;

    return Column(
      children: [
        // Date navigator
        Container(
          color: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: onPrevDay,
              ),
              Expanded(
                child: Text(
                  dayLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isToday ? Colors.white38 : Colors.white),
                onPressed: isToday ? null : onNextDay,
              ),
            ],
          ),
        ),
        // Summary chips
        if (records.isNotEmpty)
          Container(
            color: AppColors.primaryGreen.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _SummaryChip(label: 'Gelir', value: '₺${fmt.format(income)}', color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Gider', value: '₺${fmt.format(expense)}', color: AppColors.errorRed),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Net',
                  value: '${net >= 0 ? '+' : ''}₺${fmt.format(net)}',
                  color: net >= 0 ? const Color(0xFF2E7D32) : AppColors.errorRed,
                  bold: true,
                ),
              ],
            ),
          ),
        // Records
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
                  ? RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.today,
                          title: 'Bu Gün Kayıt Yok',
                          subtitle: 'Bu tarih için gelir veya gider kaydı bulunmuyor.',
                          buttonLabel: 'Kayıt Ekle',
                          onButtonTap: onAdd,
                        ),
                      ]),
                    )
                  : _RecordListView(records: records, onDelete: onDelete, onRefresh: onRefresh),
        ),
      ],
    );
  }
}

// ─── Monthly Tab ──────────────────────────────────────────────────────────────

class _MonthlyTab extends StatelessWidget {
  final int year;
  final int month;
  final List<FinanceModel> records;     // period='monthly'
  final List<FinanceModel> milkSales;   // period='daily', Süt Satışı
  final Map<String, double> summary;
  final bool loading;
  final bool isCurrentMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function() onRefresh;

  const _MonthlyTab({
    required this.year,
    required this.month,
    required this.records,
    required this.milkSales,
    required this.summary,
    required this.loading,
    required this.isCurrentMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onRefresh,
  });

  // Süt satışı açıklamasından litreyi çıkar: "Süt satışı — 50.0 L × ₺25.00"
  double _parseLiters(String? desc) {
    if (desc == null) return 0;
    final m = RegExp(r'([\d.]+)\s*L').firstMatch(desc);
    return m != null ? double.tryParse(m.group(1) ?? '') ?? 0 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(year, month));
    final income  = summary['income']  ?? 0;
    final expense = summary['expense'] ?? 0;
    final profit  = summary['profit']  ?? 0;

    // Süt satışı toplamları
    final milkTotal  = milkSales.fold(0.0, (s, r) => s + r.amount);
    final milkLiters = milkSales.fold(0.0, (s, r) => s + _parseLiters(r.description));
    final milkDays   = milkSales.length;

    // period='monthly' kayıtlarını kategoriye göre ayır
    final Map<String, double> incomeByCategory = {};
    final Map<String, double> expenseByCategory = {};
    final Map<String, int> incomeCounts = {};
    final Map<String, int> expenseCounts = {};
    for (final r in records) {
      if (r.isIncome) {
        incomeByCategory[r.category] = (incomeByCategory[r.category] ?? 0) + r.amount;
        incomeCounts[r.category] = (incomeCounts[r.category] ?? 0) + 1;
      } else {
        expenseByCategory[r.category] = (expenseByCategory[r.category] ?? 0) + r.amount;
        expenseCounts[r.category] = (expenseCounts[r.category] ?? 0) + 1;
      }
    }
    final sortedIncome  = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedExpense = expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final hasContent = records.isNotEmpty || milkSales.isNotEmpty;

    return Column(
      children: [
        // Month navigator
        Container(
          color: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: onPrevMonth),
              Expanded(
                child: Text(monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isCurrentMonth ? Colors.white38 : Colors.white),
                onPressed: isCurrentMonth ? null : onNextMonth,
              ),
            ],
          ),
        ),
        // Summary card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              _SCard(label: 'Toplam Gelir', value: '₺${fmt.format(income)}', color: const Color(0xFF2E7D32)),
              const _VDivider(),
              _SCard(label: 'Toplam Gider', value: '₺${fmt.format(expense)}', color: AppColors.errorRed),
              const _VDivider(),
              _SCard(
                label: 'Net',
                value: '${profit >= 0 ? '+' : ''}₺${fmt.format(profit)}',
                color: profit >= 0 ? const Color(0xFF2E7D32) : AppColors.errorRed,
                bold: true,
              ),
            ],
          ),
        ),
        // Category breakdown
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : !hasContent
                  ? RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView(children: [
                        const SizedBox(height: 80),
                        const EmptyState(
                          icon: Icons.calendar_month,
                          title: 'Bu Ay Kayıt Yok',
                          subtitle: 'Bu aya ait gelir veya gider kaydı bulunmuyor.',
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        // GELİRLER: süt satışı + diğer monthly gelirler
                        if (milkTotal > 0 || sortedIncome.isNotEmpty) ...[
                          _SectionBar(title: 'Gelirler', color: const Color(0xFF2E7D32), total: income),
                          // Süt satışı (günlük kayıtların aylık toplamı)
                          if (milkTotal > 0)
                            _CategoryRow(
                              category: AppConstants.incomeMilk,
                              amount: milkTotal,
                              count: milkDays,
                              total: income,
                              subtitle: milkLiters > 0
                                  ? '$milkDays günlük · ${milkLiters.toStringAsFixed(1)} L'
                                  : '$milkDays günlük satış',
                            ),
                          // Diğer monthly gelir kategorileri
                          ...sortedIncome.map((e) => _CategoryRow(
                            category: e.key,
                            amount: e.value,
                            count: incomeCounts[e.key] ?? 0,
                            total: income,
                          )),
                        ],
                        // GİDERLER
                        if (sortedExpense.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionBar(title: 'Giderler', color: AppColors.errorRed, total: expense),
                          ...sortedExpense.map((e) => _CategoryRow(
                            category: e.key,
                            amount: e.value,
                            count: expenseCounts[e.key] ?? 0,
                            total: expense,
                          )),
                        ],
                      ],
                    ),
                    ),
        ),
      ],
    );
  }
}

// ─── Records Tab ──────────────────────────────────────────────────────────────

class _RecordsTab extends StatelessWidget {
  final List<FinanceModel> records;
  final String filter;
  final bool loading;
  final Function(String) onFilterChanged;
  final Function(FinanceModel) onDelete;
  final Future<void> Function() onRefresh;

  const _RecordsTab({
    required this.records,
    required this.filter,
    required this.loading,
    required this.onFilterChanged,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = switch (filter) {
      'Gelir' => records.where((r) => r.isIncome).toList(),
      'Gider' => records.where((r) => !r.isIncome).toList(),
      _       => records,
    };

    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final f in ['Tümü', 'Gelir', 'Gider'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f, style: const TextStyle(fontSize: 13)),
                    selected: filter == f,
                    onSelected: (_) => onFilterChanged(f),
                    selectedColor: f == 'Gelir'
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                        : f == 'Gider'
                            ? AppColors.errorRed.withValues(alpha: 0.15)
                            : AppColors.primaryGreen.withValues(alpha: 0.15),
                    checkmarkColor: f == 'Gelir'
                        ? const Color(0xFF2E7D32)
                        : f == 'Gider'
                            ? AppColors.errorRed
                            : AppColors.primaryGreen,
                  ),
                ),
              const Spacer(),
              Text(
                '${filtered.length} kayıt',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView(children: [
                        const SizedBox(height: 80),
                        const EmptyState(
                          icon: Icons.list_alt,
                          title: 'Kayıt Yok',
                          subtitle: 'Seçilen filtreye uygun kayıt bulunamadı.',
                        ),
                      ]),
                    )
                  : _RecordListView(records: filtered, onDelete: onDelete, onRefresh: onRefresh),
        ),
      ],
    );
  }
}

// ─── Record List View ─────────────────────────────────────────────────────────

class _RecordListView extends StatelessWidget {
  final List<FinanceModel> records;
  final Function(FinanceModel) onDelete;
  final Future<void> Function() onRefresh;

  const _RecordListView({required this.records, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 4),
        itemCount: records.length,
        itemBuilder: (_, i) => _FinanceRecordTile(record: records[i], onDelete: onDelete),
      ),
    );
  }
}

// ─── Finance Record Tile ──────────────────────────────────────────────────────

class _FinanceRecordTile extends StatelessWidget {
  final FinanceModel record;
  final Function(FinanceModel) onDelete;

  const _FinanceRecordTile({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final isIncome = record.isIncome;
    final sideColor = isIncome ? const Color(0xFF2E7D32) : AppColors.errorRed;
    final catColor = _catColor(record.category);
    final isAuto = record.notes?.startsWith('Otomatik') ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: sideColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: catColor.withValues(alpha: 0.12),
          child: Icon(_catIcon(record.category), color: catColor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.category,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            if (isAuto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Oto',
                  style: TextStyle(fontSize: 9, color: Color(0xFF1565C0), fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.description != null && record.description!.isNotEmpty)
              Text(
                record.description!,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              DateFormat('d MMM yyyy', 'tr_TR').format(DateTime.parse(record.date)),
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : '-'}₺${fmt.format(record.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: sideColor, fontSize: 14),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onDelete(record),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.textGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Row (Aylık tab) ─────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final String category;
  final double amount;
  final int count;
  final double total;
  final String? subtitle; // Örn: "10 günlük · 500.0 L"

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.count,
    required this.total,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final catColor = _catColor(category);
    final isIncome = AppConstants.incomeCategories.contains(category);
    final amountColor = isIncome ? const Color(0xFF2E7D32) : AppColors.errorRed;
    final info = subtitle ?? '$count kayıt';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: catColor.withValues(alpha: 0.12),
                child: Icon(_catIcon(category), color: catColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(info, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${fmt.format(amount)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: amountColor, fontSize: 14),
                  ),
                  Text(
                    '%${(pct * 100).toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: catColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(catColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SummaryChip({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SCard({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final String title;
  final Color color;
  final double total;

  const _SectionBar({required this.title, required this.color, required this.total});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          const Spacer(),
          Text('₺${fmt.format(total)}', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Add Record Sheet ─────────────────────────────────────────────────────────

class _AddRecordSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final DateTime initialDate;

  const _AddRecordSheet({required this.onSaved, required this.initialDate});

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FinanceRepository();

  bool _isIncome = false;
  String? _category;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  List<String> get _categories => _isIncome ? AppConstants.incomeCategories : AppConstants.expenseCategories;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final model = FinanceModel(
      type: _isIncome ? AppConstants.income : AppConstants.expense,
      category: _category!,
      amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
      date: DateFormat('yyyy-MM-dd').format(_date),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      period: 'monthly',
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await _repo.insert(model);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  bool get _isOther =>
      _category == AppConstants.expenseOther || _category == AppConstants.incomeOther;

  @override
  Widget build(BuildContext context) {
    final incomeColor = const Color(0xFF2E7D32);
    final expenseColor = AppColors.errorRed;
    final activeColor = _isIncome ? incomeColor : expenseColor;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Kayıt Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gelir / Gider toggle
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() { _isIncome = true; _category = null; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isIncome ? incomeColor : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _isIncome ? incomeColor : Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_downward, color: _isIncome ? Colors.white : AppColors.textGrey, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Gelir', style: TextStyle(color: _isIncome ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() { _isIncome = false; _category = null; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isIncome ? expenseColor : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: !_isIncome ? expenseColor : Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_upward, color: !_isIncome ? Colors.white : AppColors.textGrey, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Gider', style: TextStyle(color: !_isIncome ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Category dropdown
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: 'Kategori *',
                          prefixIcon: _category != null
                              ? Icon(_catIcon(_category!), color: _catColor(_category!))
                              : const Icon(Icons.category_outlined),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(_catIcon(c), size: 18, color: _catColor(c)),
                              const SizedBox(width: 10),
                              Text(c),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _category = v),
                        validator: (v) => v == null ? 'Kategori seçiniz' : null,
                      ),
                      const SizedBox(height: 12),
                      // Amount
                      TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tutar *',
                          prefixText: '₺ ',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Tutar giriniz';
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Geçerli bir tutar giriniz';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Date
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                            suffixIcon: Icon(Icons.edit_calendar, size: 18),
                          ),
                          child: Text(DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(_date)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        decoration: InputDecoration(
                          labelText: 'Açıklama',
                          prefixIcon: const Icon(Icons.notes),
                          hintText: _isOther ? 'SGK, Vergi, Kira, vb.' : 'İsteğe bağlı',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(_isIncome ? Icons.add_circle : Icons.remove_circle, color: Colors.white),
                          label: Text(
                            _isIncome ? 'Gelir Kaydet' : 'Gider Kaydet',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
