import '../local/database_helper.dart';
import '../models/milking_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activity_logger.dart';
import 'tank_repository.dart';

class MilkingRepository {
  final _db = DatabaseHelper.instance;
  final _tank = TankRepository();

  Future<int> insert(MilkingModel m) async {
    final db = await _db.database;
    final map = m.toMap()..remove('id');
    final id = await db.insert('milking', map);
    await _tank.addMilking(m.amount, notes: m.animalName, date: m.date);
    ActivityLogger.instance.log(
      actionType: AppConstants.activityMilkingAdded,
      description: 'Sağım kaydı: ${m.animalName} · ${m.amount.toStringAsFixed(1)} L · ${m.session}',
      relatedRef: 'milking:$id',
    );
    return id;
  }

  Future<List<MilkingModel>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT m.*, a.earTag, a.name FROM milking m
      LEFT JOIN animals a ON m.animalId = a.id
      WHERE m.date = ? ORDER BY m.session ASC
    ''', [date]);
    return maps.map((e) => MilkingModel.fromMap(e)).toList();
  }

  Future<List<MilkingModel>> getLast30Days() async {
    final db = await _db.database;
    final from = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T').first;
    final maps = await db.rawQuery('''
      SELECT m.*, a.earTag, a.name FROM milking m
      LEFT JOIN animals a ON m.animalId = a.id
      WHERE m.date >= ? ORDER BY m.date DESC, m.session ASC
    ''', [from]);
    return maps.map((e) => MilkingModel.fromMap(e)).toList();
  }

  Future<Map<String, double>> getDailyTotals(int days) async {
    final db = await _db.database;
    final from = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T').first;
    final result = await db.rawQuery('''
      SELECT date, SUM(amount) as total FROM milking
      WHERE date >= ? GROUP BY date ORDER BY date ASC
    ''', [from]);
    return {for (var r in result) r['date'] as String: (r['total'] as num).toDouble()};
  }

  Future<double> getTodayTotal() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final individual = await db.rawQuery('SELECT SUM(amount) as total FROM milking WHERE date = ?', [today]);
    final bulk = await db.rawQuery('SELECT SUM(totalAmount) as total FROM bulk_milking WHERE date = ?', [today]);
    final ind = (individual.first['total'] as num?)?.toDouble() ?? 0.0;
    final bul = (bulk.first['total'] as num?)?.toDouble() ?? 0.0;
    return ind + bul;
  }

  Future<double> getMonthTotal() async {
    final db = await _db.database;
    final now = DateTime.now();
    final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM milking WHERE date >= ?', [from]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<MilkingModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT m.*, a.earTag, a.name FROM milking m
      LEFT JOIN animals a ON m.animalId = a.id
      ORDER BY m.date DESC, m.session ASC
    ''');
    return maps.map((e) => MilkingModel.fromMap(e)).toList();
  }

  Future<int> update(MilkingModel m) async {
    final db = await _db.database;
    final map = m.toMap()..remove('id');
    return await db.update('milking', map, where: 'id = ?', whereArgs: [m.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('milking', where: 'id = ?', whereArgs: [id]);
  }
}
