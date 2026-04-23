import '../local/database_helper.dart';
import '../models/finance_model.dart';

class FinanceRepository {
  final _db = DatabaseHelper.instance;

  Future<int> insert(FinanceModel f) async {
    final db = await _db.database;
    return await db.insert('finance', f.toMap()..remove('id'));
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
}
