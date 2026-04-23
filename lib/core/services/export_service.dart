import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/milking_repository.dart';
import '../../data/repositories/bulk_milking_repository.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/calf_repository.dart';
import '../../data/repositories/equipment_repository.dart';
import '../../data/repositories/staff_repository.dart';

class ExportService {
  static final instance = ExportService._();
  ExportService._();

  Future<void> exportAll() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1'); // varsayılan boş sheet'i sil

    await _buildAnimals(excel);
    await _buildCalves(excel);
    await _buildMilking(excel);
    await _buildHealth(excel);
    await _buildFinance(excel);
    await _buildFeed(excel);
    await _buildEquipment(excel);
    await _buildStaff(excel);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel oluşturulamadı');

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'CiftlikPro_${now.year}${_p(now.month)}${_p(now.day)}_${_p(now.hour)}${_p(now.minute)}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ÇiftlikPRO Veri Dışa Aktarma',
      text: 'ÇiftlikPRO — $fileName',
    );
  }

  // ─── Hayvanlar ────────────────────────────────────────────────────────────

  Future<void> _buildAnimals(Excel excel) async {
    final sheet = excel['Hayvanlar'];
    _header(sheet, [
      'Küpe No', 'Ad', 'Irk', 'Cinsiyet', 'Doğum Tarihi',
      'Durum', 'Ağırlık (kg)', 'Giriş Tarihi', 'Giriş Türü', 'Notlar',
    ]);
    final animals = await AnimalRepository().getAll();
    for (final a in animals) {
      sheet.appendRow([
        _t(a.earTag), _t(a.name), _t(a.breed), _t(a.gender),
        _t(a.birthDate), _t(a.status), _n(a.weight),
        _t(a.entryDate), _t(a.entryType), _t(a.notes),
      ]);
    }
    _styleHeader(sheet);
  }

  // ─── Buzağılar ────────────────────────────────────────────────────────────

  Future<void> _buildCalves(Excel excel) async {
    final sheet = excel['Buzağılar'];
    _header(sheet, [
      'Küpe No', 'Ad', 'Cinsiyet', 'Doğum Tarihi', 'Anne Küpe',
      'Baba Irkı', 'Doğum Ağırlığı (kg)', 'Durum', 'Notlar',
    ]);
    final calves = await CalfRepository().getAllCalves();
    for (final c in calves) {
      sheet.appendRow([
        _t(c.earTag), _t(c.name), _t(c.gender), _t(c.birthDate),
        _t(c.motherEarTag), _t(c.fatherBreed), _n(c.birthWeight),
        _t(c.status), _t(c.notes),
      ]);
    }
    _styleHeader(sheet);
  }

  // ─── Süt Kayıtları ────────────────────────────────────────────────────────

  Future<void> _buildMilking(Excel excel) async {
    final sheet = excel['Süt Kayıtları'];
    _header(sheet, ['Tarih', 'Seans', 'Küpe No', 'Hayvan Adı', 'Miktar (L)', 'Notlar']);
    final records = await MilkingRepository().getAll();
    for (final m in records) {
      sheet.appendRow([
        _t(m.date), _t(m.session), _t(m.animalEarTag),
        _t(m.animalName), _n(m.amount), _t(m.notes),
      ]);
    }

    // Toplu sağım kayıtları
    final bulkSheet = excel['Toplu Sağım'];
    _header(bulkSheet, ['Tarih', 'Seans', 'Hayvan Sayısı', 'Toplam Miktar (L)', 'Notlar']);
    final bulk = await BulkMilkingRepository().getAll(limit: 99999);
    for (final b in bulk) {
      bulkSheet.appendRow([
        _t(b.date), _t(b.session), _n(b.animalCount), _n(b.totalAmount), _t(b.notes),
      ]);
    }
    _styleHeader(sheet);
    _styleHeader(bulkSheet);
  }

  // ─── Sağlık & Aşı ────────────────────────────────────────────────────────

  Future<void> _buildHealth(Excel excel) async {
    final repo = HealthRepository();

    final hSheet = excel['Sağlık Kayıtları'];
    _header(hSheet, [
      'Tarih', 'Küpe No', 'Hayvan Adı', 'Tür', 'Teşhis',
      'Tedavi', 'İlaç', 'Doz', 'Veteriner', 'Maliyet (₺)', 'Sonraki Ziyaret', 'Notlar',
    ]);
    final health = await repo.getAllHealth();
    for (final h in health) {
      hSheet.appendRow([
        _t(h.date), _t(h.animalEarTag), _t(h.animalName), _t(h.type),
        _t(h.diagnosis), _t(h.treatment), _t(h.medicine), _t(h.dose),
        _t(h.vetName), _n(h.cost), _t(h.nextVisit), _t(h.notes),
      ]);
    }

    final vSheet = excel['Aşı Kayıtları'];
    _header(vSheet, [
      'Tarih', 'Küpe No', 'Hayvan Adı', 'Sürü Geneli',
      'Aşı Adı', 'Sonraki Aşı', 'Doz', 'Veteriner',
      'Maliyet (₺)', 'Seri No', 'Notlar',
    ]);
    final vaccines = await repo.getAllVaccines();
    for (final v in vaccines) {
      vSheet.appendRow([
        _t(v.vaccineDate), _t(v.animalEarTag), _t(v.animalName),
        _t(v.isHerdWide ? 'Evet' : 'Hayır'), _t(v.vaccineName),
        _t(v.nextVaccineDate), _t(v.dose), _t(v.vetName),
        _n(v.cost), _t(v.batchNumber), _t(v.notes),
      ]);
    }
    _styleHeader(hSheet);
    _styleHeader(vSheet);
  }

  // ─── Finans ───────────────────────────────────────────────────────────────

  Future<void> _buildFinance(Excel excel) async {
    final sheet = excel['Finans'];
    _header(sheet, ['Tarih', 'Tür', 'Kategori', 'Tutar (₺)', 'Açıklama', 'Fatura No', 'Notlar']);
    final records = await FinanceRepository().getAll();
    for (final f in records) {
      sheet.appendRow([
        _t(f.date), _t(f.type), _t(f.category), _n(f.amount),
        _t(f.description), _t(f.invoiceNo), _t(f.notes),
      ]);
    }
    _styleHeader(sheet);
  }

  // ─── Yem ──────────────────────────────────────────────────────────────────

  Future<void> _buildFeed(Excel excel) async {
    final repo = FeedRepository();

    final sSheet = excel['Yem Stokları'];
    _header(sSheet, ['Ad', 'Tür', 'Miktar', 'Birim', 'Min. Stok', 'Durum', 'Notlar']);
    final stocks = await repo.getAllStocks();
    for (final s in stocks) {
      sSheet.appendRow([
        _t(s.name), _t(s.type), _n(s.quantity), _t(s.unit),
        _n(s.minQuantity), _t(s.isLow ? 'Kritik' : 'Normal'), _t(s.notes),
      ]);
    }

    final tSheet = excel['Yem Hareketleri'];
    _header(tSheet, ['Tarih', 'Stok Adı', 'İşlem', 'Miktar', 'Birim', 'Notlar']);
    final txns = await repo.getRecentTransactions(limit: 9999);
    for (final t in txns) {
      tSheet.appendRow([
        _t(t.date), _t(t.stockName), _t(t.transactionType), _n(t.quantity), _t(t.unit), _t(t.notes),
      ]);
    }
    _styleHeader(sSheet);
    _styleHeader(tSheet);
  }

  // ─── Ekipman ──────────────────────────────────────────────────────────────

  Future<void> _buildEquipment(Excel excel) async {
    final sheet = excel['Ekipmanlar'];
    _header(sheet, [
      'Ad', 'Kategori', 'Marka', 'Model', 'Seri No',
      'Alım Tarihi', 'Alım Fiyatı (₺)', 'Durum',
      'Son Bakım', 'Sonraki Bakım', 'Notlar',
    ]);
    final items = await EquipmentRepository().getAll();
    for (final e in items) {
      sheet.appendRow([
        _t(e.name), _t(e.category), _t(e.brand), _t(e.model), _t(e.serialNumber),
        _t(e.purchaseDate?.toIso8601String().split('T').first),
        _n(e.purchasePrice), _t(e.status),
        _t(e.lastMaintenanceDate?.toIso8601String().split('T').first),
        _t(e.nextMaintenanceDate?.toIso8601String().split('T').first),
        _t(e.notes),
      ]);
    }
    _styleHeader(sheet);
  }

  // ─── Personel ─────────────────────────────────────────────────────────────

  Future<void> _buildStaff(Excel excel) async {
    final sheet = excel['Personel'];
    _header(sheet, ['Ad Soyad', 'Pozisyon', 'Telefon', 'E-posta', 'İşe Başlama', 'Maaş (₺)', 'Durum', 'Notlar']);
    final staff = await StaffRepository().getAllStaff();
    for (final s in staff) {
      sheet.appendRow([
        _t(s.name), _t(s.role), _t(s.phone), _t(s.email),
        _t(s.startDate?.toIso8601String().split('T').first),
        _n(s.salary), _t(s.isActive ? 'Aktif' : 'Pasif'), _t(s.notes),
      ]);
    }
    _styleHeader(sheet);
  }

  // ─── Yardımcılar ──────────────────────────────────────────────────────────

  void _header(Sheet sheet, List<String> columns) {
    sheet.appendRow(columns.map((c) => TextCellValue(c)).toList());
  }

  void _styleHeader(Sheet sheet) {
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1B5E20'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    final firstRow = sheet.rows.firstOrNull;
    if (firstRow == null) return;
    for (final cell in firstRow) {
      if (cell != null) cell.cellStyle = headerStyle;
    }
  }

  CellValue _t(String? v) => TextCellValue(v ?? '');
  CellValue _n(num? v) => v != null ? DoubleCellValue(v.toDouble()) : TextCellValue('');
  String _p(int v) => v.toString().padLeft(2, '0');
}
