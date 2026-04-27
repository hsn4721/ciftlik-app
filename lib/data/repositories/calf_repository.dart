import '../local/database_helper.dart';
import '../models/calf_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activity_logger.dart';

class CalfRepository {
  final _db = DatabaseHelper.instance;

  Future<int> insertCalf(CalfModel c) async {
    final db = await _db.database;
    final id = await db.insert('calves', c.toMap()..remove('id'));
    ActivityLogger.instance.log(
      actionType: AppConstants.activityCalfAdded,
      description: 'Yeni buzağı: ${c.name ?? c.earTag} · ${c.gender}',
      relatedRef: 'calves:$id',
    );
    return id;
  }

  Future<List<CalfModel>> getAllCalves() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT c.*, a.earTag as motherEarTag FROM calves c
      LEFT JOIN animals a ON c.motherId = a.id
      ORDER BY c.birthDate DESC
    ''');
    return maps.map((e) => CalfModel.fromMap(e)).toList();
  }

  Future<int> updateCalf(CalfModel c) async {
    final db = await _db.database;
    return await db.update('calves', c.toMap()..remove('id'), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteCalf(int id) async {
    final db = await _db.database;
    return await db.delete('calves', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertBreeding(BreedingModel b) async {
    final db = await _db.database;
    return await db.insert('breeding', b.toMap()..remove('id'));
  }

  Future<List<BreedingModel>> getAllBreedings() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT b.*, a.earTag, a.name FROM breeding b
      LEFT JOIN animals a ON b.animalId = a.id
      ORDER BY b.breedingDate DESC
    ''');
    return maps.map((e) => BreedingModel.fromMap(e)).toList();
  }

  Future<List<BreedingModel>> getUpcomingBirths(int days) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String().split('T').first;
    final future = DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;
    final maps = await db.rawQuery('''
      SELECT b.*, a.earTag, a.name FROM breeding b
      LEFT JOIN animals a ON b.animalId = a.id
      WHERE b.expectedBirthDate BETWEEN ? AND ? AND b.status = 'Gebe'
      ORDER BY b.expectedBirthDate ASC
    ''', [now, future]);
    return maps.map((e) => BreedingModel.fromMap(e)).toList();
  }

  Future<int> updateBreeding(BreedingModel b) async {
    final db = await _db.database;
    return await db.update('breeding', b.toMap()..remove('id'), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<int> deleteBreeding(int id) async {
    final db = await _db.database;
    return await db.delete('breeding', where: 'id = ?', whereArgs: [id]);
  }
}
