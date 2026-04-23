import '../local/database_helper.dart';
import '../models/health_model.dart';
import '../models/finance_model.dart';
import '../../core/constants/app_constants.dart';
import 'finance_repository.dart';

class HealthRepository {
  final _db = DatabaseHelper.instance;
  final _financeRepo = FinanceRepository();

  Future<int> insertHealth(HealthModel h) async {
    final db = await _db.database;
    final id = await db.insert('health', h.toMap()..remove('id'));

    // Veteriner ücreti girilmişse → finansa otomatik gider
    if (h.cost != null && h.cost! > 0) {
      try {
        final desc = StringBuffer('${h.type} — ${h.animalEarTag}');
        if (h.vetName != null && h.vetName!.isNotEmpty) desc.write(' (${h.vetName})');
        if (h.diagnosis != null && h.diagnosis!.isNotEmpty) desc.write(': ${h.diagnosis}');
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.expense,
          category: AppConstants.expenseVet,
          amount: h.cost!,
          date: h.date,
          description: desc.toString(),
          relatedAnimalId: h.animalId,
          notes: 'Otomatik - Sağlık Modülü',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {}
    }

    return id;
  }

  Future<List<HealthModel>> getAllHealth() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT h.*, a.earTag, a.name FROM health h
      LEFT JOIN animals a ON h.animalId = a.id
      ORDER BY h.date DESC
    ''');
    return maps.map((e) => HealthModel.fromMap(e)).toList();
  }

  Future<List<HealthModel>> getHealthByAnimal(int animalId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT h.*, a.earTag, a.name FROM health h
      LEFT JOIN animals a ON h.animalId = a.id
      WHERE h.animalId = ? ORDER BY h.date DESC
    ''', [animalId]);
    return maps.map((e) => HealthModel.fromMap(e)).toList();
  }

  Future<int> updateHealth(HealthModel h) async {
    final db = await _db.database;
    final map = h.toMap()..remove('id');
    return await db.update('health', map, where: 'id = ?', whereArgs: [h.id]);
  }

  Future<int> deleteHealth(int id) async {
    final db = await _db.database;
    return await db.delete('health', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertVaccine(VaccineModel v) async {
    final db = await _db.database;
    final id = await db.insert('vaccines', v.toMap()..remove('id'));

    // Aşı maliyeti girilmişse → finansa otomatik gider
    if (v.cost != null && v.cost! > 0) {
      try {
        final desc = StringBuffer('${v.vaccineName} aşısı');
        if (v.isHerdWide) {
          desc.write(' (Sürü geneli)');
        } else if (v.animalEarTag != null && v.animalEarTag!.isNotEmpty) {
          desc.write(' — ${v.animalEarTag}');
        }
        if (v.vetName != null && v.vetName!.isNotEmpty) desc.write(' (${v.vetName})');
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.expense,
          category: AppConstants.expenseVet,
          amount: v.cost!,
          date: v.vaccineDate,
          description: desc.toString(),
          relatedAnimalId: v.animalId,
          notes: 'Otomatik - Sağlık Modülü',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {}
    }

    return id;
  }

  Future<List<VaccineModel>> getAllVaccines() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT v.*, a.earTag, a.name FROM vaccines v
      LEFT JOIN animals a ON v.animalId = a.id
      ORDER BY v.vaccineDate DESC
    ''');
    return maps.map((e) => VaccineModel.fromMap(e)).toList();
  }

  Future<List<VaccineModel>> getUpcomingVaccines(int days) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String().split('T').first;
    final future = DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;
    final maps = await db.rawQuery('''
      SELECT v.*, a.earTag, a.name FROM vaccines v
      LEFT JOIN animals a ON v.animalId = a.id
      WHERE v.nextVaccineDate BETWEEN ? AND ?
      ORDER BY v.nextVaccineDate ASC
    ''', [now, future]);
    return maps.map((e) => VaccineModel.fromMap(e)).toList();
  }

  Future<int> updateVaccine(VaccineModel v) async {
    final db = await _db.database;
    final map = v.toMap()..remove('id');
    return await db.update('vaccines', map, where: 'id = ?', whereArgs: [v.id]);
  }

  Future<int> deleteVaccine(int id) async {
    final db = await _db.database;
    return await db.delete('vaccines', where: 'id = ?', whereArgs: [id]);
  }
}
