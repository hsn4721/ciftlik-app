import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/module_header.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/finance_stats.dart';
import '../../core/services/finance_pdf_service.dart';
import '../../core/services/payment_reminder_sync.dart';
import '../../data/models/finance_model.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/masked_amount.dart';
import '../../shared/widgets/undo_snackbar.dart';
import 'analysis_tab.dart';

// ─── Category helpers ────────────────────────────────────────────────────────

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

const _incomeColor = Color(0xFF2E7D32);
final _expenseColor = AppColors.errorRed;
final _fmt = NumberFormat('#,##0.00', 'tr_TR');
final _fmtShort = NumberFormat('#,##0', 'tr_TR');

// ─── Main Screen ─────────────────────────────────────────────────────────────

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _repo = FinanceRepository();
  final _stats = FinanceStats();

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  FinanceMonthReport? _report;
  List<FinanceModel> _unpaid = [];
  List<FinanceModel> _all = [];
  bool _loading = true;

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
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait([
      _stats.loadMonth(_year, _month),
      _repo.getUnpaid(),
      _repo.getAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _report = results[0] as FinanceMonthReport;
      _unpaid = results[1] as List<FinanceModel>;
      _all = results[2] as List<FinanceModel>;
      _loading = false;
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; }
      else _month--;
    });
    _reload();
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_month == 12) { _month = 1; _year++; }
      else _month++;
    });
    _reload();
  }

  Future<void> _delete(FinanceModel f) async {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.canManageFinance) {
      // Partner salt-okunur — silme yetkisi yok
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu işlem için yetkiniz yok')),
      );
      return;
    }
    if (f.isAuto) {
      _showAutoRecordInfo(f);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('${f.category} — ₺${_fmt.format(f.amount)} silinsin mi?'),
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
      // Geri al desteği için kaydı önce belleğe al
      final backup = f;
      await _repo.delete(f.id!);
      await PaymentReminderSync.onDelete(f.id!);
      _reload();
      if (mounted) {
        UndoSnackbar.show(
          context,
          message: '${backup.category} — ₺${_fmt.format(backup.amount)} silindi',
          onUndo: () async {
            // Aynı veriyi (id hariç) yeniden ekle
            await _repo.insert(backup.copyWith(id: null));
            _reload();
          },
        );
      }
    }
  }

  void _showAutoRecordInfo(FinanceModel f) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Otomatik Kayıt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(f.sourceLabel,
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                'Bu kayıt ${f.sourceLabel}\'nden otomatik olarak oluşturuldu. '
                'Değişiklik yapmak veya silmek için ilgili modülü kullanın; '
                'böylece maliyet ve stok bilgileri tutarlı kalır.',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Kategori', f.category),
                    _kv('Tutar', '₺${_fmt.format(f.amount)}'),
                    _kv('Tarih', DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.parse(f.date))),
                    if (f.description != null) _kv('Açıklama', f.description!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Anladım',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 72, child: Text('$k:', style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddRecordSheet(onSaved: _reload, initialDate: DateTime.now()),
    );
  }

  Future<void> _togglePaid(FinanceModel f) async {
    if (f.id == null) return;
    final user = AuthService.instance.currentUser;
    if (user != null && !user.canManageFinance) return; // Partner yetkisi yok
    final updated = f.copyWith(isPaid: !f.isPaid);
    await _repo.update(updated);
    await PaymentReminderSync.onSave(updated);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelir & Gider'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Dışa Aktar',
            enabled: !_loading && _report != null,
            onSelected: _handleExport,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pdf_monthly',
                enabled: _all.isNotEmpty,
                child: const _ExportItem(
                  icon: Icons.picture_as_pdf,
                  color: Color(0xFFC62828),
                  title: 'Aylık Finans Raporu (PDF)',
                  subtitle: 'KPI, birim ekonomi, kategori, detay',
                ),
              ),
              PopupMenuItem(
                value: 'pdf_pending',
                enabled: _unpaid.isNotEmpty,
                child: _ExportItem(
                  icon: Icons.pending_actions,
                  color: AppColors.gold,
                  title: 'Bekleyen Ödemeler (PDF)',
                  subtitle: _unpaid.isEmpty ? 'Bekleyen yok' : '${_unpaid.length} kayıt',
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'excel',
                enabled: _all.isNotEmpty,
                child: const _ExportItem(
                  icon: Icons.table_chart,
                  color: Color(0xFF2E7D32),
                  title: 'Excel (XLSX)',
                  subtitle: 'Tüm kayıtlar + özet',
                ),
              ),
            ],
          ),
          Builder(builder: (_) {
            final u = AuthService.instance.currentUser;
            if (u != null && !u.canManageFinance) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAddSheet,
              tooltip: 'Kayıt Ekle',
            );
          }),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Özet'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'İşlemler'),
            Tab(icon: Icon(Icons.insights, size: 18), text: 'Analiz'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const ModuleBackground(pattern: ModulePattern.finance),
          TabBarView(
            controller: _tab,
            children: [
              _SummaryTab(
                year: _year,
                month: _month,
                report: _report,
                unpaid: _unpaid,
                loading: _loading,
                isCurrentMonth: _isCurrentMonth,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
                onRefresh: _reload,
                onPendingTap: () {
                  _tab.animateTo(1);
                },
                onTogglePaid: _togglePaid,
              ),
              _TransactionsTab(
                all: _all,
                loading: _loading,
                onRefresh: _reload,
                onDelete: _delete,
                onTap: (r) {
                  if (r.isAuto) {
                    _showAutoRecordInfo(r);
                  } else {
                    _editManual(r);
                  }
                },
                onTogglePaid: _togglePaid,
                onAdd: _showAddSheet,
              ),
              // Analiz: anahtar grafikler (son 30 gün trend + son 6 ay + pie'lar).
              // Key ile seçili ayın değişmesinde widget yeniden oluşturulur ki
              // pie chart güncel veriyle gelsin.
              _loading || _report == null
                  ? const Center(child: CircularProgressIndicator())
                  : AnalysisTab(
                      key: ValueKey('$_year-$_month'),
                      year: _year,
                      month: _month,
                      incomeByCategory: _report!.incomeByCategory,
                      expenseByCategory: _report!.expenseByCategory,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editManual(FinanceModel r) async {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.canManageFinance) {
      // Partner salt-okunur — kayıt detayını göster, düzenlemeye izin verme
      _showAutoRecordInfo(r);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddRecordSheet(
        onSaved: _reload,
        initialDate: DateTime.parse(r.date),
        initial: r,
      ),
    );
  }

  // ─── Export handlers ───────────────────────────────────────────────────────
  Future<void> _handleExport(String action) async {
    if (_report == null) return;
    if (action == 'excel') {
      await _exportExcel();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('PDF hazırlanıyor...'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      Uint8List bytes;
      String filename;
      String subject;
      if (action == 'pdf_monthly') {
        final monthRecords = _all.where((r) {
          final d = DateTime.tryParse(r.date);
          return d != null && d.year == _year && d.month == _month
              && r.source != AppConstants.srcFeedDaily;
        }).toList();
        bytes = await FinancePdfService.instance.buildMonthlyReport(
          report: _report!,
          monthRecords: monthRecords,
          unpaid: _unpaid,
        );
        final monthKey = DateFormat('MMMM_yyyy', 'tr_TR').format(DateTime(_year, _month));
        final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_year, _month));
        filename = 'CiftlikPRO_Finans_$monthKey.pdf';
        subject = 'ÇiftlikPRO Finans Raporu — $monthLabel';
      } else if (action == 'pdf_pending') {
        bytes = await FinancePdfService.instance.buildPendingReport(unpaid: _unpaid);
        filename = 'CiftlikPRO_Bekleyen_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        subject = 'ÇiftlikPRO Bekleyen Ödemeler';
      } else {
        messenger.hideCurrentSnackBar();
        return;
      }
      messenger.hideCurrentSnackBar();
      if (mounted) {
        await _showPdfActionSheet(bytes: bytes, filename: filename, subject: subject);
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Rapor oluşturulamadı: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _showPdfActionSheet({
    required Uint8List bytes,
    required String filename,
    required String subject,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Row(children: [
                Icon(Icons.picture_as_pdf, color: Color(0xFFC62828)),
                SizedBox(width: 10),
                Text('PDF Hazır', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(filename,
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ),
              const SizedBox(height: 16),
              _PdfAction(
                icon: Icons.save_alt,
                iconColor: AppColors.primaryGreen,
                title: 'Cihaza Kaydet / Yazdır',
                subtitle: 'Sistem diyaloğu — Downloads klasörüne veya yazıcıya gönder',
                onTap: () async {
                  Navigator.pop(ctx);
                  await FinancePdfService.instance.printOrSave(bytes, filename: filename);
                },
              ),
              const SizedBox(height: 8),
              _PdfAction(
                icon: Icons.share,
                iconColor: const Color(0xFF1565C0),
                title: 'Paylaş',
                subtitle: 'WhatsApp, e-posta, Drive, vb.',
                onTap: () async {
                  Navigator.pop(ctx);
                  await FinancePdfService.instance
                      .shareBytes(bytes, filename: filename, subject: subject);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Excel Export ──────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    final report = _report;
    if (report == null) return;
    final monthLabel = DateFormat('MMMM_yyyy', 'tr_TR').format(DateTime(_year, _month));
    final monthLabelDisplay = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_year, _month));
    final numFmt = NumberFormat('#,##0.00', 'tr_TR');
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());

    final excel = Excel.createExcel();
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
    sheetOzet.appendRow([TextCellValue('ÇiftlikPRO Finans Raporu')]);
    sheetOzet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(bold: true, fontSize: 14);
    sheetOzet.appendRow([TextCellValue('Dönem: $monthLabelDisplay')]);
    sheetOzet.appendRow([TextCellValue('Rapor tarihi: $today')]);
    sheetOzet.appendRow([TextCellValue('')]);

    addRow(sheetOzet, ['GELİRLER', 'Tutar (₺)'], bold: true);
    for (final e in report.incomeByCategory.entries) {
      sheetOzet.appendRow([TextCellValue(e.key), TextCellValue(numFmt.format(e.value))]);
    }
    addRow(sheetOzet, ['TOPLAM GELİR', numFmt.format(report.income)], bold: true);
    sheetOzet.appendRow([TextCellValue('')]);

    addRow(sheetOzet, ['GİDERLER', 'Tutar (₺)'], bold: true);
    for (final e in report.expenseByCategory.entries) {
      sheetOzet.appendRow([TextCellValue(e.key), TextCellValue(numFmt.format(e.value))]);
    }
    addRow(sheetOzet, ['TOPLAM GİDER', numFmt.format(report.expense)], bold: true);
    sheetOzet.appendRow([TextCellValue('')]);
    addRow(sheetOzet, ['NET KÂR / ZARAR', numFmt.format(report.net)], bold: true);
    if (report.margin != null) {
      addRow(sheetOzet, ['Kâr Marjı (%)', report.margin!.toStringAsFixed(1)]);
    }
    sheetOzet.appendRow([TextCellValue('')]);

    addRow(sheetOzet, ['BİRİM EKONOMİ', ''], bold: true);
    if (report.costPerLiter != null) {
      addRow(sheetOzet, ['₺/litre süt (direkt maliyet)', numFmt.format(report.costPerLiter!)]);
    }
    if (report.costPerAnimal != null) {
      addRow(sheetOzet, ['Hayvan başı aylık gider', numFmt.format(report.costPerAnimal!)]);
    }
    if (report.feedCostRatio != null) {
      addRow(sheetOzet, ['Yem maliyet oranı (%)', report.feedCostRatio!.toStringAsFixed(1)]);
    }
    addRow(sheetOzet, ['Aylık süt üretimi (L)', numFmt.format(report.milkProductionLiters)]);
    addRow(sheetOzet, ['Hayvan sayısı', report.animalCount.toString()]);

    sheetOzet.setColumnWidth(0, 32);
    sheetOzet.setColumnWidth(1, 18);

    // ── Tüm Kayıtlar sayfası ─────────────────────────────────────────────
    final sheetAll = excel['Tüm Kayıtlar'];
    addRow(sheetAll, ['Tarih', 'Tür', 'Kategori', 'Tutar (₺)', 'Açıklama', 'Kaynak', 'Ödeme', 'Durum'], bold: true);
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
        TextCellValue(r.sourceLabel),
        TextCellValue(r.paymentLabel),
        TextCellValue(r.isPaid ? 'Ödendi' : 'Bekliyor'),
      ]);
    }
    sheetAll.setColumnWidth(0, 12);
    sheetAll.setColumnWidth(1, 8);
    sheetAll.setColumnWidth(2, 20);
    sheetAll.setColumnWidth(3, 14);
    sheetAll.setColumnWidth(4, 36);
    sheetAll.setColumnWidth(5, 18);
    sheetAll.setColumnWidth(6, 10);
    sheetAll.setColumnWidth(7, 10);

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
}

// ─── Özet Tab ────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final int year;
  final int month;
  final FinanceMonthReport? report;
  final List<FinanceModel> unpaid;
  final bool loading;
  final bool isCurrentMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function() onRefresh;
  final VoidCallback onPendingTap;
  final Function(FinanceModel) onTogglePaid;

  const _SummaryTab({
    required this.year,
    required this.month,
    required this.report,
    required this.unpaid,
    required this.loading,
    required this.isCurrentMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onRefresh,
    required this.onPendingTap,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(year, month));

    return Column(
      children: [
        // Ay navigator
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
        Expanded(
          child: loading || report == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _KpiGrid(report: report!),
                      if (unpaid.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _PendingBox(unpaid: unpaid, onTap: onPendingTap, onTogglePaid: onTogglePaid),
                      ],
                      const SizedBox(height: 12),
                      _UnitMetricsCard(report: report!),
                      const SizedBox(height: 12),
                      if (report!.incomeByCategory.isNotEmpty)
                        _CategorySection(
                          title: 'Gelir Dağılımı',
                          color: _incomeColor,
                          totals: report!.incomeByCategory,
                          grandTotal: report!.income,
                        ),
                      if (report!.expenseByCategory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _CategorySection(
                          title: 'Gider Dağılımı',
                          color: _expenseColor,
                          totals: report!.expenseByCategory,
                          grandTotal: report!.expense,
                        ),
                      ],
                      if (report!.income == 0 && report!.expense == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: EmptyState(
                            icon: Icons.calendar_month,
                            title: 'Bu Ay Kayıt Yok',
                            subtitle: 'Bu aya ait gelir veya gider kaydı bulunmuyor.',
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── KPI 2x2 Grid ────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final FinanceMonthReport report;
  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(
              label: 'Gelir',
              value: '₺${_fmt.format(report.income)}',
              change: report.incomeChange,
              color: _incomeColor,
              icon: Icons.arrow_downward,
            )),
            const SizedBox(width: 8),
            Expanded(child: _KpiCard(
              label: 'Gider',
              value: '₺${_fmt.format(report.expense)}',
              change: report.expenseChange,
              color: _expenseColor,
              icon: Icons.arrow_upward,
              // Giderlerde artış kötüdür — ters renk
              invertTrend: true,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _KpiCard(
              label: 'Net Kâr',
              value: '${report.net >= 0 ? '+' : ''}₺${_fmt.format(report.net)}',
              change: report.netChange,
              color: report.net >= 0 ? _incomeColor : _expenseColor,
              icon: report.net >= 0 ? Icons.trending_up : Icons.trending_down,
              bold: true,
            )),
            const SizedBox(width: 8),
            Expanded(child: _KpiCard(
              label: 'Kâr Marjı',
              value: report.margin != null
                  ? '%${report.margin!.toStringAsFixed(1)}'
                  : '—',
              change: null,
              color: (report.margin ?? 0) >= 0 ? _incomeColor : _expenseColor,
              icon: Icons.percent,
              maskable: false, // yüzde, para değil
            )),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final double? change;
  final Color color;
  final IconData icon;
  final bool bold;
  final bool invertTrend;
  /// true ise tutarın değeri gizlenebilir (para) — yüzde/rasyon için false.
  final bool maskable;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.change,
    required this.color,
    required this.icon,
    this.bold = false,
    this.invertTrend = false,
    this.maskable = true,
  });

  @override
  Widget build(BuildContext context) {
    // Trend rengi: gelir/net'te + iyi, giderde + kötü
    final trendPositive = change != null &&
        (invertTrend ? change! < 0 : change! > 0);
    final trendColor = change == null
        ? AppColors.textGrey
        : trendPositive
            ? _incomeColor
            : _expenseColor;
    final trendIcon = change == null
        ? null
        : change! > 0
            ? Icons.north_east
            : change! < 0
                ? Icons.south_east
                : Icons.remove;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          maskable
              ? MaskedAmount(
                  text: value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: bold ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: bold ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(trendIcon, size: 12, color: trendColor),
                const SizedBox(width: 2),
                Text(
                  '${change! >= 0 ? '+' : ''}${change!.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: trendColor),
                ),
                const SizedBox(width: 4),
                const Text('geçen ay', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bekleyen Ödemeler Kutusu ────────────────────────────────────────────────

class _PendingBox extends StatelessWidget {
  final List<FinanceModel> unpaid;
  final VoidCallback onTap;
  final Function(FinanceModel) onTogglePaid;

  const _PendingBox({required this.unpaid, required this.onTap, required this.onTogglePaid});

  @override
  Widget build(BuildContext context) {
    final total = unpaid.fold(0.0, (s, r) => s + r.amount);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.pending_actions, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${unpaid.length} bekleyen ödeme',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark),
                  ),
                  Text(
                    'Toplam ₺${_fmt.format(total)} — İncele',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

// ─── Birim Ekonomi Kartı ─────────────────────────────────────────────────────

class _UnitMetricsCard extends StatelessWidget {
  final FinanceMonthReport report;
  const _UnitMetricsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.analytics_outlined, size: 18, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Birim Ekonomi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ]),
          const SizedBox(height: 12),
          _metricRow(
            icon: Icons.water_drop,
            label: '₺/Litre Süt',
            value: report.costPerLiter != null
                ? '₺${report.costPerLiter!.toStringAsFixed(2)}'
                : '—',
            hint: 'Direkt maliyet (yem + vet + işçi) ÷ üretilen litre',
          ),
          _metricRow(
            icon: Icons.pets,
            label: 'Hayvan Başı Aylık Gider',
            value: report.costPerAnimal != null
                ? '₺${_fmt.format(report.costPerAnimal!)}'
                : '—',
            hint: '${report.animalCount} aktif hayvan için',
          ),
          _metricRow(
            icon: Icons.grass,
            label: 'Yem Maliyet Oranı',
            value: report.feedCostRatio != null
                ? '%${report.feedCostRatio!.toStringAsFixed(1)}'
                : '—',
            hint: 'Yem gideri / toplam gider',
          ),
          _metricRow(
            icon: Icons.local_drink,
            label: 'Aylık Süt Üretimi',
            value: '${_fmtShort.format(report.milkProductionLiters)} L',
            hint: 'Bireysel + toplu sağım toplam',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _metricRow({
    required IconData icon,
    required String label,
    required String value,
    required String hint,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text(hint, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
        ],
      ),
    );
  }
}

// ─── Kategori Breakdown (Gelir/Gider) ────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String title;
  final Color color;
  final Map<String, double> totals;
  final double grandTotal;

  const _CategorySection({
    required this.title,
    required this.color,
    required this.totals,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('₺${_fmt.format(grandTotal)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 12),
          ...sorted.map((e) => _CategoryRow(
                category: e.key,
                amount: e.value,
                total: grandTotal,
              )),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final double amount;
  final double total;

  const _CategoryRow({required this.category, required this.amount, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final catColor = _catColor(category);
    final isIncome = AppConstants.incomeCategories.contains(category);
    final amountColor = isIncome ? _incomeColor : _expenseColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: catColor.withValues(alpha: 0.12),
                child: Icon(_catIcon(category), color: catColor, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('₺${_fmt.format(amount)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: amountColor)),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: Text('%${(pct * 100).toStringAsFixed(1)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: catColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(catColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── İşlemler Tab ────────────────────────────────────────────────────────────

enum _DateRange { all, thisMonth, last7, last30, custom }
enum _TypeFilter { all, income, expense }
enum _SourceFilter { all, auto, manual }
enum _PaidFilter { all, paid, pending }

class _TransactionsTab extends StatefulWidget {
  final List<FinanceModel> all;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Function(FinanceModel) onDelete;
  final Function(FinanceModel) onTap;
  final Function(FinanceModel) onTogglePaid;
  final VoidCallback onAdd;

  const _TransactionsTab({
    required this.all,
    required this.loading,
    required this.onRefresh,
    required this.onDelete,
    required this.onTap,
    required this.onTogglePaid,
    required this.onAdd,
  });

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  _DateRange _dateRange = _DateRange.thisMonth;
  _TypeFilter _type = _TypeFilter.all;
  _SourceFilter _source = _SourceFilter.all;
  _PaidFilter _paid = _PaidFilter.all;
  DateTimeRange? _customRange;

  List<FinanceModel> get _filtered {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;
    switch (_dateRange) {
      case _DateRange.all:
        break;
      case _DateRange.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case _DateRange.last7:
        from = now.subtract(const Duration(days: 7));
        to = now;
        break;
      case _DateRange.last30:
        from = now.subtract(const Duration(days: 30));
        to = now;
        break;
      case _DateRange.custom:
        from = _customRange?.start;
        to = _customRange?.end;
        break;
    }

    // Günlük yemleme (feed_daily) kayıtları "analitik tüketim"dir —
    // gerçek nakit çıkışı değil. İşlemler akışına dahil edilmez
    // (stoktan düşen maliyet zaten Yem Modülü'nden takip edilir).
    return widget.all.where((r) => r.source != AppConstants.srcFeedDaily).where((r) {
      final d = DateTime.tryParse(r.date);
      if (d == null) return false;
      if (from != null && d.isBefore(DateTime(from.year, from.month, from.day))) return false;
      if (to != null && d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) return false;

      if (_type == _TypeFilter.income && !r.isIncome) return false;
      if (_type == _TypeFilter.expense && r.isIncome) return false;

      if (_source == _SourceFilter.auto && !r.isAuto) return false;
      if (_source == _SourceFilter.manual && r.isAuto) return false;

      if (_paid == _PaidFilter.paid && !r.isPaid) return false;
      if (_paid == _PaidFilter.pending && r.isPaid) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // tarih bazında grupla
    final groups = <String, List<FinanceModel>>{};
    for (final r in filtered) {
      (groups[r.date] ??= []).add(r);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final income = filtered.where((r) => r.isIncome).fold(0.0, (s, r) => s + r.amount);
    final expense = filtered.where((r) => !r.isIncome).fold(0.0, (s, r) => s + r.amount);

    return Column(
      children: [
        // Filtre barı
        _FilterBar(
          dateRange: _dateRange,
          type: _type,
          source: _source,
          paid: _paid,
          customRange: _customRange,
          onDateRangeChanged: (v) async {
            if (v == _DateRange.custom) {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _customRange,
              );
              if (picked != null) {
                setState(() { _dateRange = v; _customRange = picked; });
              }
            } else {
              setState(() => _dateRange = v);
            }
          },
          onTypeChanged: (v) => setState(() => _type = v),
          onSourceChanged: (v) => setState(() => _source = v),
          onPaidChanged: (v) => setState(() => _paid = v),
        ),
        // Seçili dönem özeti
        Container(
          color: AppColors.primaryGreen.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _miniStat('Gelir', '₺${_fmt.format(income)}', _incomeColor),
              const SizedBox(width: 12),
              _miniStat('Gider', '₺${_fmt.format(expense)}', _expenseColor),
              const Spacer(),
              Text('${filtered.length} kayıt',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
        ),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      child: ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.list_alt,
                          title: 'Kayıt Yok',
                          subtitle: 'Seçilen filtreye uygun kayıt bulunmuyor.',
                          buttonLabel: 'Manuel Kayıt Ekle',
                          onButtonTap: widget.onAdd,
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 4),
                        itemCount: sortedDates.length,
                        itemBuilder: (_, i) {
                          final date = sortedDates[i];
                          final items = groups[date]!;
                          final dt = DateTime.parse(date);
                          final dateLabel = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(dt);
                          final dayIncome = items.where((r) => r.isIncome).fold(0.0, (s, r) => s + r.amount);
                          final dayExpense = items.where((r) => !r.isIncome).fold(0.0, (s, r) => s + r.amount);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                                child: Row(
                                  children: [
                                    Text(dateLabel,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textGrey)),
                                    const Spacer(),
                                    if (dayIncome > 0)
                                      Text('+₺${_fmt.format(dayIncome)}',
                                          style: const TextStyle(fontSize: 11, color: _incomeColor, fontWeight: FontWeight.w700)),
                                    if (dayIncome > 0 && dayExpense > 0) const SizedBox(width: 8),
                                    if (dayExpense > 0)
                                      Text('-₺${_fmt.format(dayExpense)}',
                                          style: TextStyle(fontSize: 11, color: _expenseColor, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              ...items.map((r) => _TxTile(
                                    record: r,
                                    onTap: () => widget.onTap(r),
                                    onDelete: () => widget.onDelete(r),
                                    onTogglePaid: () => widget.onTogglePaid(r),
                                  )),
                            ],
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// ─── Filter Bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _DateRange dateRange;
  final _TypeFilter type;
  final _SourceFilter source;
  final _PaidFilter paid;
  final DateTimeRange? customRange;
  final Function(_DateRange) onDateRangeChanged;
  final Function(_TypeFilter) onTypeChanged;
  final Function(_SourceFilter) onSourceChanged;
  final Function(_PaidFilter) onPaidChanged;

  const _FilterBar({
    required this.dateRange,
    required this.type,
    required this.source,
    required this.paid,
    required this.customRange,
    required this.onDateRangeChanged,
    required this.onTypeChanged,
    required this.onSourceChanged,
    required this.onPaidChanged,
  });

  String _dateLabel() {
    switch (dateRange) {
      case _DateRange.all:       return 'Tümü';
      case _DateRange.thisMonth: return 'Bu Ay';
      case _DateRange.last7:     return 'Son 7 Gün';
      case _DateRange.last30:    return 'Son 30 Gün';
      case _DateRange.custom:
        if (customRange == null) return 'Özel';
        final f = DateFormat('d MMM', 'tr_TR');
        return '${f.format(customRange!.start)} - ${f.format(customRange!.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        children: [
          // Tarih seçici
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final r in _DateRange.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            r == dateRange ? _dateLabel() : _labelFor(r),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: r == dateRange,
                          onSelected: (_) => onDateRangeChanged(r),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
          // Tür / Kaynak / Ödeme filtreleri
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _pill('Tümü', type == _TypeFilter.all, () => onTypeChanged(_TypeFilter.all)),
                _pill('Gelir', type == _TypeFilter.income, () => onTypeChanged(_TypeFilter.income), _incomeColor),
                _pill('Gider', type == _TypeFilter.expense, () => onTypeChanged(_TypeFilter.expense), _expenseColor),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),
                _pill('Tüm Kaynak', source == _SourceFilter.all, () => onSourceChanged(_SourceFilter.all)),
                _pill('Otomatik', source == _SourceFilter.auto, () => onSourceChanged(_SourceFilter.auto), const Color(0xFF1565C0)),
                _pill('Manuel', source == _SourceFilter.manual, () => onSourceChanged(_SourceFilter.manual)),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),
                _pill('Tüm Durum', paid == _PaidFilter.all, () => onPaidChanged(_PaidFilter.all)),
                _pill('Ödendi', paid == _PaidFilter.paid, () => onPaidChanged(_PaidFilter.paid), _incomeColor),
                _pill('Bekliyor', paid == _PaidFilter.pending, () => onPaidChanged(_PaidFilter.pending), AppColors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(_DateRange r) {
    switch (r) {
      case _DateRange.all:       return 'Tümü';
      case _DateRange.thisMonth: return 'Bu Ay';
      case _DateRange.last7:     return 'Son 7 Gün';
      case _DateRange.last30:    return 'Son 30 Gün';
      case _DateRange.custom:    return 'Özel';
    }
  }

  Widget _pill(String label, bool selected, VoidCallback onTap, [Color? highlight]) {
    final color = highlight ?? AppColors.primaryGreen;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: 0.15),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─── Transaction Tile ────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final FinanceModel record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePaid;

  const _TxTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = record.isIncome;
    final sideColor = isIncome ? _incomeColor : _expenseColor;
    final catColor = _catColor(record.category);

    return Dismissible(
      key: Key('tx-${record.id}'),
      direction: record.isAuto ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorRed.withValues(alpha: 0.15),
        child: const Icon(Icons.delete, color: AppColors.errorRed),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // delete handled externally
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: sideColor, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: catColor.withValues(alpha: 0.12),
                child: Icon(_catIcon(record.category), color: catColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(record.category,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        if (record.isAuto) _badge(
                          icon: Icons.link,
                          text: record.sourceLabel,
                          color: const Color(0xFF1565C0),
                        ),
                      ],
                    ),
                    if (record.description != null && record.description!.isNotEmpty)
                      Text(record.description!,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        if (!record.isPaid)
                          _badge(
                            icon: Icons.pending_actions,
                            text: 'Bekliyor',
                            color: AppColors.gold,
                          ),
                        if (!record.isPaid) const SizedBox(width: 6),
                        if (record.paymentMethod != AppConstants.pmCash)
                          Text(record.paymentLabel,
                              style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MaskedAmount(
                    text: '${isIncome ? '+' : '-'}₺${_fmt.format(record.amount)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: sideColor, fontSize: 14),
                  ),
                  if (!record.isPaid)
                    InkWell(
                      onTap: onTogglePaid,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text('Ödendi işaretle',
                            style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, decoration: TextDecoration.underline)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Add / Edit Record Sheet ─────────────────────────────────────────────────

class AddRecordSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final DateTime initialDate;
  final FinanceModel? initial; // düzenleme modu için

  const AddRecordSheet({super.key, required this.onSaved, required this.initialDate, this.initial});

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FinanceRepository();

  late bool _isIncome;
  String? _category;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _vatCtrl;
  late DateTime _date;
  late String _paymentMethod;
  late bool _isPaid;
  DateTime? _dueDate;
  bool _saving = false;
  bool _showAdvanced = false;

  bool get _isEditing => widget.initial != null;

  List<String> get _categories => _isIncome ? AppConstants.incomeCategories : AppConstants.expenseCategories;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isIncome = init != null ? init.isIncome : false;
    _category = init?.category;
    _amountCtrl = TextEditingController(text: init != null ? init.amount.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _vatCtrl = TextEditingController(text: init?.vatRate?.toString() ?? '');
    _date = init != null ? DateTime.parse(init.date) : widget.initialDate;
    _paymentMethod = init?.paymentMethod ?? AppConstants.pmCash;
    _isPaid = init?.isPaid ?? true;
    _dueDate = init?.dueDate != null ? DateTime.tryParse(init!.dueDate!) : null;
    _showAdvanced = init != null && (
      init.paymentMethod != AppConstants.pmCash ||
      !init.isPaid ||
      init.vatRate != null
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _vatCtrl.dispose();
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

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vatRate = _vatCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_vatCtrl.text.replaceAll(',', '.'));

    final model = FinanceModel(
      id: widget.initial?.id,
      type: _isIncome ? AppConstants.income : AppConstants.expense,
      category: _category!,
      amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
      date: DateFormat('yyyy-MM-dd').format(_date),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      period: 'monthly',
      createdAt: widget.initial?.createdAt ?? DateTime.now().toIso8601String(),
      source: widget.initial?.source ?? AppConstants.srcManual,
      sourceRef: widget.initial?.sourceRef,
      paymentMethod: _paymentMethod,
      isPaid: _paymentMethod == AppConstants.pmDeferred ? _isPaid : true,
      dueDate: _paymentMethod == AppConstants.pmDeferred
          ? (_dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null)
          : null,
      vatRate: vatRate,
    );

    try {
      FinanceModel saved;
      if (_isEditing) {
        await _repo.update(model);
        saved = model;
      } else {
        final id = await _repo.insert(model);
        saved = model.copyWith(id: id);
      }
      // Vadeli ödeme hatırlatıcısını senkronla
      await PaymentReminderSync.onSave(saved);
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

  @override
  Widget build(BuildContext context) {
    final activeColor = _isIncome ? _incomeColor : _expenseColor;
    final autoHint = _category != null ? AppConstants.autoCategoryHint[_category!] : null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(_isEditing ? 'Kaydı Düzenle' : 'Kayıt Ekle',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gelir/Gider toggle (düzenlemede de kullanılabilir)
                      Row(
                        children: [
                          Expanded(child: _typeToggle(true, 'Gelir', Icons.arrow_downward, _incomeColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _typeToggle(false, 'Gider', Icons.arrow_upward, _expenseColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: 'Kategori *',
                          prefixIcon: _category != null
                              ? Icon(_catIcon(_category!), color: _catColor(_category!))
                              : const Icon(Icons.category_outlined),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Icon(_catIcon(c), size: 18, color: _catColor(c)),
                            const SizedBox(width: 10),
                            Text(c),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _category = v),
                        validator: (v) => v == null ? 'Kategori seçiniz' : null,
                      ),
                      // Otomatik kategori uyarısı
                      if (autoHint != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppColors.gold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  autoHint + ' Çift kayıt olmaması için mümkünse oradan ekleyin.',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
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
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
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
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          prefixIcon: Icon(Icons.notes),
                          hintText: 'İsteğe bağlı',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                        child: Row(children: [
                          Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.primaryGreen),
                          const SizedBox(width: 4),
                          const Text('Gelişmiş: Ödeme / KDV',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
                        ]),
                      ),
                      if (_showAdvanced) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
        initialValue: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Ödeme Yöntemi',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          items: AppConstants.paymentMethods.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(AppConstants.paymentMethodLabel[p]!),
                          )).toList(),
                          onChanged: (v) => setState(() {
                            _paymentMethod = v ?? AppConstants.pmCash;
                            if (_paymentMethod != AppConstants.pmDeferred) {
                              _isPaid = true;
                              _dueDate = null;
                            } else {
                              _isPaid = false;
                            }
                          }),
                        ),
                        if (_paymentMethod == AppConstants.pmDeferred) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: _isPaid,
                            onChanged: (v) => setState(() => _isPaid = v),
                            title: const Text('Ödeme yapıldı mı?', style: TextStyle(fontSize: 13)),
                            subtitle: Text(_isPaid ? 'Ödendi olarak işaretli' : 'Bekleyen ödeme',
                                style: TextStyle(fontSize: 11, color: _isPaid ? _incomeColor : AppColors.gold)),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primaryGreen,
                          ),
                          if (!_isPaid) ...[
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _pickDueDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Son Ödeme Tarihi',
                                  prefixIcon: Icon(Icons.event, size: 18),
                                ),
                                child: Text(_dueDate != null
                                    ? DateFormat('d MMMM yyyy', 'tr_TR').format(_dueDate!)
                                    : 'Seçiniz'),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vatCtrl,
                          decoration: const InputDecoration(
                            labelText: 'KDV Oranı (%) — opsiyonel',
                            prefixIcon: Icon(Icons.receipt_long),
                            hintText: 'Örn: 10',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                      const SizedBox(height: 20),
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
                              : Icon(_isEditing ? Icons.save : (_isIncome ? Icons.add_circle : Icons.remove_circle), color: Colors.white),
                          label: Text(
                            _isEditing ? 'Değişiklikleri Kaydet' : (_isIncome ? 'Gelir Kaydet' : 'Gider Kaydet'),
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

  Widget _typeToggle(bool income, String label, IconData icon, Color color) {
    final selected = _isIncome == income;
    return GestureDetector(
      onTap: () => setState(() { _isIncome = income; _category = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.textGrey, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: selected ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── PDF aksiyon satırı (bottomsheet için) ───────────────────────────────────

class _PdfAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PdfAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

// ─── Export menü item'ı (PopupMenuButton için) ───────────────────────────────

class _ExportItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ExportItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ],
    );
  }
}
