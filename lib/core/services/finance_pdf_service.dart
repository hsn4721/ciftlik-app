import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/finance_model.dart';
import 'finance_stats.dart';

/// ÇiftlikPRO finans PDF raporlarını üretir.
///
/// - `buildXxx()` metotları yalnızca PDF byte'ı döner
/// - `shareBytes()` ile paylaşma dialogu açılır
/// - `printOrSave()` ile Android'in sistem yazdır/kaydet diyaloğu açılır
///
/// Türkçe karakter desteği için Google Fonts (NotoSans) kullanılır
/// (ilk kullanımda internet gerekir, cache'lenir).
class FinancePdfService {
  FinancePdfService._();
  static final FinancePdfService instance = FinancePdfService._();

  pw.Font? _regular;
  pw.Font? _bold;
  pw.MemoryImage? _logo;

  // Renkler
  static const _green = PdfColor.fromInt(0xFF1B5E20);
  static const _lightGreen = PdfColor.fromInt(0xFFE8F5E9);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _lightRed = PdfColor.fromInt(0xFFFFEBEE);
  static const _gold = PdfColor.fromInt(0xFFF9A825);
  static const _lightGold = PdfColor.fromInt(0xFFFFF8E1);
  static const _grey = PdfColor.fromInt(0xFF757575);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const _dark = PdfColor.fromInt(0xFF212121);

  static final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  /// Türkçe fontlar + uygulama logosunu (bir kez) yükler.
  Future<void> _ensureAssets() async {
    if (_regular != null && _bold != null && _logo != null) return;
    try {
      _regular ??= await PdfGoogleFonts.notoSansRegular();
      _bold ??= await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      _regular ??= pw.Font.helvetica();
      _bold ??= pw.Font.helveticaBold();
    }
    if (_logo == null) {
      try {
        final data = await rootBundle.load('assets/images/app_icon.png');
        _logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        _logo = null; // Logo yoksa sadece metin başlık
      }
    }
  }

  // ─── Public build API ────────────────────────────────────────────────────

  Future<Uint8List> buildMonthlyReport({
    required FinanceMonthReport report,
    required List<FinanceModel> monthRecords,
    required List<FinanceModel> unpaid,
  }) async {
    await _ensureAssets();
    final doc = pw.Document(title: 'ÇiftlikPRO Finans Raporu', author: 'ÇiftlikPRO');
    final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(report.year, report.month));
    final today = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
          theme: theme,
        ),
        header: (ctx) => _buildHeader(monthLabel, today),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildKpiBlock(report),
          pw.SizedBox(height: 14),
          _buildUnitEconomicsBlock(report),
          pw.SizedBox(height: 14),
          if (report.incomeByCategory.isNotEmpty) ...[
            _buildCategoryTable(
              title: 'Gelir Kategorileri',
              totals: report.incomeByCategory,
              totalSum: report.income,
              accent: _green,
              accentLight: _lightGreen,
            ),
            pw.SizedBox(height: 14),
          ],
          if (report.expenseByCategory.isNotEmpty) ...[
            _buildCategoryTable(
              title: 'Gider Kategorileri',
              totals: report.expenseByCategory,
              totalSum: report.expense,
              accent: _red,
              accentLight: _lightRed,
            ),
            pw.SizedBox(height: 14),
          ],
          if (unpaid.isNotEmpty) ...[
            _buildPendingSection(unpaid),
            pw.SizedBox(height: 14),
          ],
          _buildRecordsTable(monthRecords),
        ],
      ),
    );

    return await doc.save();
  }

  Future<Uint8List> buildPendingReport({required List<FinanceModel> unpaid}) async {
    await _ensureAssets();
    final doc = pw.Document(title: 'Bekleyen Ödemeler', author: 'ÇiftlikPRO');
    final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
    final today = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
    final total = unpaid.fold(0.0, (s, r) => s + r.amount);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
          theme: theme,
        ),
        header: (ctx) => _buildHeader('Bekleyen Ödemeler', today),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _lightGold,
              border: pw.Border.all(color: _gold, width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(children: [
              pw.Text('Toplam Bekleyen Ödeme:',
                  style: pw.TextStyle(fontSize: 12, color: _dark)),
              pw.Spacer(),
              pw.Text('TL ${_fmt.format(total)}',
                  style: pw.TextStyle(fontSize: 14, color: _dark, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 14),
          _buildPendingTable(unpaid),
        ],
      ),
    );

    return await doc.save();
  }

  // ─── Share / Print actions ────────────────────────────────────────────────

  /// Paylaş — WhatsApp, mail, Drive, vb.
  Future<void> shareBytes(Uint8List bytes, {required String filename, required String subject}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
    );
  }

  /// Yazdır / PDF olarak kaydet — Android'in sistem print diyaloğu açılır.
  /// Kullanıcı "PDF olarak kaydet" seçerek Downloads'a kaydedebilir.
  Future<void> printOrSave(Uint8List bytes, {required String filename}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
    );
  }

  // ─── Header / Footer ─────────────────────────────────────────────────────

  pw.Widget _buildHeader(String subtitle, String reportDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _green, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (_logo != null) ...[
            pw.Container(
              width: 42, height: 42,
              decoration: pw.BoxDecoration(
                color: _lightGreen,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(_logo!, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ÇiftlikPRO',
                  style: pw.TextStyle(fontSize: 20, color: _green, fontWeight: pw.FontWeight.bold)),
              pw.Text('Finans Raporu',
                  style: pw.TextStyle(fontSize: 10, color: _grey)),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(subtitle,
                  style: pw.TextStyle(fontSize: 14, color: _dark, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rapor tarihi: $reportDate',
                  style: pw.TextStyle(fontSize: 9, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _lightGrey, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('ÇiftlikPRO', style: pw.TextStyle(fontSize: 9, color: _grey)),
          pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _grey)),
        ],
      ),
    );
  }

  // ─── KPI Block ───────────────────────────────────────────────────────────

  pw.Widget _buildKpiBlock(FinanceMonthReport r) {
    final netColor = r.net >= 0 ? _green : _red;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AYLIK ÖZET',
              style: pw.TextStyle(fontSize: 11, color: _grey, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _kpiCell('Toplam Gelir', 'TL ${_fmt.format(r.income)}', _green, r.incomeChange, false),
            pw.SizedBox(width: 8),
            _kpiCell('Toplam Gider', 'TL ${_fmt.format(r.expense)}', _red, r.expenseChange, true),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _kpiCell('Net Kar / Zarar',
                '${r.net >= 0 ? '+' : ''}TL ${_fmt.format(r.net)}', netColor, r.netChange, false),
            pw.SizedBox(width: 8),
            _kpiCell('Kar Marji',
                r.margin != null ? '%${r.margin!.toStringAsFixed(1)}' : '—',
                netColor, null, false),
          ]),
        ],
      ),
    );
  }

  pw.Widget _kpiCell(String label, String value, PdfColor color, double? change, bool invertTrend) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _grey)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, color: color, fontWeight: pw.FontWeight.bold)),
            if (change != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% gecen aya gore',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: ((invertTrend ? change < 0 : change > 0) ? _green : _red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Unit Economics ──────────────────────────────────────────────────────

  pw.Widget _buildUnitEconomicsBlock(FinanceMonthReport r) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGrey, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('BİRİM EKONOMİ',
              style: pw.TextStyle(fontSize: 11, color: _grey, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.SizedBox(height: 10),
          _metricRow('TL/Litre Süt (Direkt Maliyet)',
              r.costPerLiter != null ? 'TL ${r.costPerLiter!.toStringAsFixed(2)}' : '—'),
          _metricRow('Hayvan Basi Aylik Gider',
              r.costPerAnimal != null ? 'TL ${_fmt.format(r.costPerAnimal!)}' : '—'),
          _metricRow('Yem Maliyet Orani',
              r.feedCostRatio != null ? '%${r.feedCostRatio!.toStringAsFixed(1)}' : '—'),
          _metricRow('Aylik Sut Uretimi', '${_fmt.format(r.milkProductionLiters)} L'),
          _metricRow('Aktif Hayvan Sayisi', r.animalCount.toString(), isLast: true),
        ],
      ),
    );
  }

  pw.Widget _metricRow(String k, String v, {bool isLast = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontSize: 10, color: _dark))),
        pw.Text(v, style: pw.TextStyle(fontSize: 11, color: _green, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  // ─── Category Table ──────────────────────────────────────────────────────

  pw.Widget _buildCategoryTable({
    required String title,
    required Map<String, double> totals,
    required double totalSum,
    required PdfColor accent,
    required PdfColor accentLight,
  }) {
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGrey, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(width: 3, height: 14, color: accent),
            pw.SizedBox(width: 6),
            pw.Text(title.toUpperCase(),
                style: pw.TextStyle(fontSize: 11, color: _grey, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
            pw.Spacer(),
            pw.Text('TL ${_fmt.format(totalSum)}',
                style: pw.TextStyle(fontSize: 11, color: accent, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: _lightGrey, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: accentLight),
                children: [
                  _th('Kategori'),
                  _th('Tutar', align: pw.TextAlign.right),
                  _th('Pay', align: pw.TextAlign.right),
                ],
              ),
              for (final e in sorted)
                pw.TableRow(children: [
                  _td(e.key),
                  _td('TL ${_fmt.format(e.value)}', align: pw.TextAlign.right, bold: true),
                  _td(totalSum > 0 ? '%${(e.value / totalSum * 100).toStringAsFixed(1)}' : '—',
                      align: pw.TextAlign.right),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Pending Section ─────────────────────────────────────────────────────

  pw.Widget _buildPendingSection(List<FinanceModel> unpaid) {
    final total = unpaid.fold(0.0, (s, r) => s + r.amount);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lightGold,
        border: pw.Border.all(color: _gold, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Text('BEKLEYEN ODEMELER',
                style: pw.TextStyle(fontSize: 11, color: _dark, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
            pw.Spacer(),
            pw.Text('${unpaid.length} kayit · TL ${_fmt.format(total)}',
                style: pw.TextStyle(fontSize: 11, color: _dark, fontWeight: pw.FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildPendingTable(List<FinanceModel> unpaid) {
    return pw.Table(
      border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightGold),
          children: [
            _th('Kategori'),
            _th('Aciklama'),
            _th('Tutar', align: pw.TextAlign.right),
            _th('Son Odeme'),
            _th('Durum'),
          ],
        ),
        for (final r in unpaid)
          pw.TableRow(children: [
            _td(r.category),
            _td(r.description ?? '—'),
            _td('TL ${_fmt.format(r.amount)}', align: pw.TextAlign.right, bold: true),
            _td(r.dueDate != null
                ? DateFormat('d MMM yyyy', 'tr_TR').format(DateTime.parse(r.dueDate!))
                : '—'),
            _td(_overdueLabel(r.dueDate), color: _overdueColor(r.dueDate)),
          ]),
      ],
    );
  }

  String _overdueLabel(String? dueDate) {
    if (dueDate == null) return 'Bekliyor';
    final due = DateTime.parse(dueDate);
    final diff = due.difference(DateTime.now()).inDays;
    if (diff < 0) return '${-diff} gun gecikmis';
    if (diff == 0) return 'Bugun';
    return '$diff gun sonra';
  }

  PdfColor _overdueColor(String? dueDate) {
    if (dueDate == null) return _grey;
    final due = DateTime.parse(dueDate);
    final diff = due.difference(DateTime.now()).inDays;
    if (diff < 0) return _red;
    if (diff <= 7) return _gold;
    return _grey;
  }

  // ─── Records Table ───────────────────────────────────────────────────────

  pw.Widget _buildRecordsTable(List<FinanceModel> records) {
    final sorted = List<FinanceModel>.from(records)
      ..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Container(width: 3, height: 14, color: _green),
          pw.SizedBox(width: 6),
          pw.Text('DETAYLI KAYIT LİSTESİ',
              style: pw.TextStyle(fontSize: 11, color: _grey, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.Spacer(),
          pw.Text('${sorted.length} kayıt',
              style: pw.TextStyle(fontSize: 10, color: _grey)),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(2.2),
            3: pw.FlexColumnWidth(3),
            4: pw.FlexColumnWidth(1.6),
            5: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lightGrey),
              children: [
                _th('Tarih'),
                _th('Tur'),
                _th('Kategori'),
                _th('Aciklama'),
                _th('Tutar', align: pw.TextAlign.right),
                _th('Kaynak'),
              ],
            ),
            for (final r in sorted)
              pw.TableRow(children: [
                _td(DateFormat('dd.MM.yyyy').format(DateTime.parse(r.date))),
                _td(r.type, color: r.isIncome ? _green : _red, bold: true),
                _td(r.category),
                _td(r.description ?? '—'),
                _td('${r.isIncome ? '+' : '-'}TL ${_fmt.format(r.amount)}',
                    align: pw.TextAlign.right,
                    color: r.isIncome ? _green : _red,
                    bold: true),
                _td(r.sourceLabel, color: _grey),
              ]),
          ],
        ),
      ],
    );
  }

  // ─── Table cell helpers ──────────────────────────────────────────────────

  pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(fontSize: 9, color: _dark, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _td(String text,
      {pw.TextAlign align = pw.TextAlign.left, PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          color: color ?? _dark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
