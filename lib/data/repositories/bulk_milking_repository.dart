import '../local/database_helper.dart';
import '../models/bulk_milking_model.dart';
import 'tank_repository.dart';

class BulkMilkingRepository {
  final _db = DatabaseHelper.instance;
  final _tank = TankRepository();

  Future<int> insert(BulkMilkingModel m) async {
    final db = await _db.database;
    final map = m.toMap()..remove('id');
    final id = await db.insert('bulk_milking', map);
    await _tank.addBulkMilking(m.totalAmount, notes: '${m.session} sağım', date: m.date);
    return id;
  }

  Future<List<BulkMilkingModel>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query('bulk_milking',
        where: 'date = ?', whereArgs: [date], orderBy: 'session ASC');
    return maps.map((e) => BulkMilkingModel.fromMap(e)).toList();
  }

  Future<List<BulkMilkingModel>> getAll({int limit = 60}) async {
    final db = await _db.database;
    final maps = await db.query('bulk_milking',
        orderBy: 'date DESC, session ASC', limit: limit);
    return maps.map((e) => BulkMilkingModel.fromMap(e)).toList();
  }

  Future<double> getTodayTotal() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await db.rawQuery(
        'SELECT SUM(totalAmount) as total FROM bulk_milking WHERE date = ?', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthTotal() async {
    final db = await _db.database;
    final now = DateTime.now();
    final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final result = await db.rawQuery(
        'SELECT SUM(totalAmount) as total FROM bulk_milking WHERE date >= ?', [from]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getDailyTotals(int days) async {
    final db = await _db.database;
    final from = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .split('T')
        .first;
    final result = await db.rawQuery('''
      SELECT date, SUM(totalAmount) as total FROM bulk_milking
      WHERE date >= ? GROUP BY date ORDER BY date ASC
    ''', [from]);
    return {for (var r in result) r['date'] as String: (r['total'] as num).toDouble()};
  }

  Future<int> update(BulkMilkingModel m) async {
    final db = await _db.database;
    final map = m.toMap()..remove('id');
    return await db.update('bulk_milking', map, where: 'id = ?', whereArgs: [m.id]);
  }

  Future<int> delete(int id, double amount) async {
    final db = await _db.database;
    await _tank.deduct(amount, notes: 'Kayıt silindi');
    return await db.delete('bulk_milking', where: 'id = ?', whereArgs: [id]);
  }
}
