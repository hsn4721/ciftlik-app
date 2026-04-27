import 'package:intl/intl.dart';
import '../local/database_helper.dart';
import '../models/finance_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activity_logger.dart';

/// Günlük nakit akışı noktası — line chart için.
class DailyCashflowPoint {
  final DateTime date;
  final double income;
  final double expense;
  const DailyCashflowPoint({required this.date, required this.income, required this.expense});
  double get net => income - expense;
}

/// Aylık nakit akışı noktası — bar chart için.
class MonthlyCashflowPoint {
  final int year;
  final int month;
  final double income;
  final double expense;
  const MonthlyCashflowPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });
  double get net => income - expense;
}

class FinanceRepository {
  final _db = DatabaseHelper.instance;

  Future<int> insert(FinanceModel f) async {
    final db = await _db.database;
    final id = await db.insert('finance', f.toMap()..remove('id'));
    // Otomatik (modüllerden gelen) finans kayıtları zaten kaynak modülde loglanır.
    // Sadece manuel girişleri burada loglarız.
    if (f.source == AppConstants.srcManual) {
      ActivityLogger.instance.log(
        actionType: AppConstants.activityFinanceAdded,
        description: '${f.isIncome ? 'Gelir' : 'Gider'}: ${f.category} · '
            '₺${f.amount.toStringAsFixed(0)}',
        relatedRef: 'finance:$id',
      );
    }
    return id;
  }

  Future<List<FinanceModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('finance', orderBy: 'date DESC, createdAt DESC');
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  Future<List<FinanceModel>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query('finance',
        where: 'date = ?', whereArgs: [date], orderBy: 'createdAt DESC');
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  /// Günlük sekmesi için: operasyonel kayıtlar (günlük yemleme, süt satışı,
  /// aşı/vet, vb.). Stok alımı gibi "aylığa yazılan" büyük yatırım
  /// kayıtları hariç tutulur — çünkü günlük tüketim zaten stoktan düşüyor,
  /// ikinci kez günlük görünümde saymak kullanıcıyı yanıltır.
  Future<List<FinanceModel>> getDailyViewByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query(
      'finance',
      where: "date = ? AND source != 'feed_purchase'",
      whereArgs: [date],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  Future<List<FinanceModel>> getByMonth(int year, int month) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final maps = await db.query('finance',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [from, to],
        orderBy: 'date DESC, createdAt DESC');
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  Future<Map<String, double>> getMonthSummary(int year, int month) async {
    final records = await getByMonth(year, month);
    double income = 0, expense = 0;
    for (final r in records) {
      if (r.isIncome) income += r.amount;
      else expense += r.amount;
    }
    return {'income': income, 'expense': expense, 'profit': income - expense};
  }

  // Sadece period='monthly' kayıtları — aylık özet ekranı için
  Future<List<FinanceModel>> getMonthlyOnly(int year, int month) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final maps = await db.query('finance',
        where: "date BETWEEN ? AND ? AND period = 'monthly'",
        whereArgs: [from, to],
        orderBy: 'date DESC, createdAt DESC');
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  // Ay içindeki süt satışı kayıtları (period='daily', category=Süt Satışı)
  Future<List<FinanceModel>> getMilkSalesByMonth(int year, int month) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final maps = await db.query('finance',
        where: "date BETWEEN ? AND ? AND period = 'daily' AND category = 'Süt Satışı'",
        whereArgs: [from, to],
        orderBy: 'date ASC');
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  // Aylık özet: period='monthly' + süt satışları birlikte
  Future<Map<String, double>> getMonthSummaryMonthlyOnly(int year, int month) async {
    final monthly = await getMonthlyOnly(year, month);
    final milk = await getMilkSalesByMonth(year, month);
    double income = 0, expense = 0;
    for (final r in [...monthly, ...milk]) {
      if (r.isIncome) income += r.amount;
      else expense += r.amount;
    }
    return {'income': income, 'expense': expense, 'profit': income - expense};
  }

  Future<int> update(FinanceModel f) async {
    final db = await _db.database;
    return await db.update('finance', f.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [f.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('finance', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Yeni sorgular (Faz 2) ───────────────────────────────────────────────

  /// Bekleyen (henüz ödenmemiş) kayıtlar — özet kutusu için.
  Future<List<FinanceModel>> getUnpaid() async {
    final db = await _db.database;
    final maps = await db.query(
      'finance',
      where: 'isPaid = 0',
      orderBy: 'dueDate ASC, date ASC',
    );
    return maps.map((e) => FinanceModel.fromMap(e)).toList();
  }

  /// İki ay arası gelir/gider kıyası — önceki aya göre yüzde değişim.
  /// Süt satışı (period='daily') + monthly kayıtlar birlikte sayılır.
  Future<Map<String, double>> getMonthTotals(int year, int month) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    // period='monthly' kayıtlar + period='daily' süt satışı (çift sayıma
    // dahil olmayan tek daily kategori) → aylık nakit akışı.
    final maps = await db.rawQuery('''
      SELECT type, SUM(amount) as total FROM finance
      WHERE date BETWEEN ? AND ?
        AND (period = 'monthly' OR category = 'Süt Satışı')
      GROUP BY type
    ''', [from, to]);
    double income = 0, expense = 0;
    for (final r in maps) {
      final amt = (r['total'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'Gelir') income = amt;
      else if (r['type'] == 'Gider') expense = amt;
    }
    return {'income': income, 'expense': expense, 'profit': income - expense};
  }

  /// Belirtilen kategori toplamları (breakdown için).
  Future<Map<String, double>> getCategoryTotals(
      int year, int month, {required bool isIncome}) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final typeFilter = isIncome ? 'Gelir' : 'Gider';
    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total FROM finance
      WHERE date BETWEEN ? AND ? AND type = ?
        AND (period = 'monthly' OR category = 'Süt Satışı')
      GROUP BY category ORDER BY total DESC
    ''', [from, to, typeFilter]);
    return {
      for (final r in maps)
        r['category'] as String: (r['total'] as num).toDouble()
    };
  }

  /// Son N günün günlük gelir/gider toplamları — line chart için.
  /// Eksik günler 0 ile doldurulur; sonuç tam N+1 giriş içerir.
  /// Sadece nakit akışını yansıtan kayıtlar (period='monthly' + süt satışı).
  Future<List<DailyCashflowPoint>> getDailyCashflow(int days) async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final rows = await db.rawQuery('''
      SELECT date,
             SUM(CASE WHEN type = 'Gelir' THEN amount ELSE 0 END) as income,
             SUM(CASE WHEN type = 'Gider' THEN amount ELSE 0 END) as expense
      FROM finance
      WHERE date >= ?
        AND (period = 'monthly' OR category = 'Süt Satışı')
      GROUP BY date
      ORDER BY date ASC
    ''', [startStr]);

    final byDate = {
      for (final r in rows)
        r['date'] as String: DailyCashflowPoint(
          date: DateTime.parse(r['date'] as String),
          income: (r['income'] as num?)?.toDouble() ?? 0,
          expense: (r['expense'] as num?)?.toDouble() ?? 0,
        ),
    };

    // Tüm günleri doldur (eksik günler sıfır)
    final result = <DailyCashflowPoint>[];
    for (int i = 0; i <= days; i++) {
      final d = start.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      result.add(byDate[key] ?? DailyCashflowPoint(date: d, income: 0, expense: 0));
    }
    return result;
  }

  /// Son N ayın gelir/gider toplamları — bar chart için. En eskiden yeniye sıralı.
  Future<List<MonthlyCashflowPoint>> getLastMonthsCashflow(int months) async {
    final db = await _db.database;
    final now = DateTime.now();
    final startYear = now.month - months + 1 <= 0
        ? now.year - 1
        : now.year;
    final startMonth = ((now.month - months) % 12 + 12) % 12 + 1;
    final startDate = DateTime(startYear, startMonth, 1);
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);

    final rows = await db.rawQuery('''
      SELECT substr(date, 1, 7) as ym,
             SUM(CASE WHEN type = 'Gelir' THEN amount ELSE 0 END) as income,
             SUM(CASE WHEN type = 'Gider' THEN amount ELSE 0 END) as expense
      FROM finance
      WHERE date >= ?
        AND (period = 'monthly' OR category = 'Süt Satışı')
      GROUP BY ym
      ORDER BY ym ASC
    ''', [startStr]);

    final byYm = {
      for (final r in rows)
        r['ym'] as String: (
          (r['income'] as num?)?.toDouble() ?? 0.0,
          (r['expense'] as num?)?.toDouble() ?? 0.0,
        ),
    };

    // Eksik ayları doldur
    final result = <MonthlyCashflowPoint>[];
    for (int i = 0; i < months; i++) {
      final d = DateTime(startDate.year, startDate.month + i, 1);
      final key = DateFormat('yyyy-MM').format(d);
      final vals = byYm[key];
      result.add(MonthlyCashflowPoint(
        year: d.year,
        month: d.month,
        income: vals?.$1 ?? 0,
        expense: vals?.$2 ?? 0,
      ));
    }
    return result;
  }

  /// Bir dönemin süt üretim litresi (milking + bulk_milking) — ₺/litre için.
  Future<double> getMonthMilkProduction(int year, int month) async {
    final db = await _db.database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final ind = await db.rawQuery(
      'SELECT SUM(amount) as total FROM milking WHERE date BETWEEN ? AND ?',
      [from, to],
    );
    final bulk = await db.rawQuery(
      'SELECT SUM(totalAmount) as total FROM bulk_milking WHERE date BETWEEN ? AND ?',
      [from, to],
    );
    final i = (ind.first['total'] as num?)?.toDouble() ?? 0;
    final b = (bulk.first['total'] as num?)?.toDouble() ?? 0;
    return i + b;
  }
}
