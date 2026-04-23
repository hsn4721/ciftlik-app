import '../local/database_helper.dart';
import '../models/animal_model.dart';
import '../models/finance_model.dart';
import '../../core/constants/app_constants.dart';
import 'finance_repository.dart';

class AnimalRepository {
  final _db = DatabaseHelper.instance;
  final _financeRepo = FinanceRepository();

  Future<int> insert(AnimalModel animal) async {
    final db = await _db.database;
    final id = await db.insert('animals', animal.toMap()..remove('id'));

    // Satın alma ise → finansa otomatik gider
    if (animal.entryType == 'Satın Alma' &&
        animal.purchasePrice != null &&
        animal.purchasePrice! > 0) {
      try {
        final label = animal.name != null && animal.name!.isNotEmpty
            ? '${animal.name} (${animal.earTag})'
            : animal.earTag;
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.expense,
          category: AppConstants.expenseAnimal,
          amount: animal.purchasePrice!,
          date: animal.entryDate,
          description: 'Hayvan alımı — $label ${animal.breed}',
          notes: 'Otomatik - Sürü Modülü',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {}
    }

    return id;
  }

  // Sadece aktif (çıkmamış) hayvanlar
  Future<List<AnimalModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('animals',
        where: 'exitType IS NULL', orderBy: 'earTag ASC');
    return maps.map((m) => AnimalModel.fromMap(m)).toList();
  }

  // Çıkarılmış hayvanlar (tarihsel kayıt)
  Future<List<AnimalModel>> getRemoved() async {
    final db = await _db.database;
    final maps = await db.query('animals',
        where: 'exitType IS NOT NULL', orderBy: 'exitDate DESC');
    return maps.map((m) => AnimalModel.fromMap(m)).toList();
  }

  Future<List<AnimalModel>> getByStatus(String status) async {
    final db = await _db.database;
    final maps = await db.query('animals',
        where: 'status = ? AND exitType IS NULL',
        whereArgs: [status],
        orderBy: 'earTag ASC');
    return maps.map((m) => AnimalModel.fromMap(m)).toList();
  }

  Future<AnimalModel?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('animals', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AnimalModel.fromMap(maps.first);
  }

  Future<int> update(AnimalModel animal) async {
    final db = await _db.database;
    return await db.update('animals', animal.toMap(),
        where: 'id = ?', whereArgs: [animal.id]);
  }

  // Hayvan çıkarma: durumu günceller, finans kaydı oluşturur
  Future<void> removeAnimal({
    required AnimalModel animal,
    required String reason,
    double? exitPrice,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final today = now.split('T').first;

    final statusMap = {
      'Satış': AppConstants.animalSold,
      'Ölüm': AppConstants.animalDead,
      'Kesim': AppConstants.animalSlaughtered,
      'Hibe': AppConstants.animalSold,
      'Kayıp': AppConstants.animalDead,
      'Diğer': animal.status,
    };

    await db.update('animals', {
      'exitType': reason,
      'exitDate': today,
      'exitPrice': exitPrice,
      'status': statusMap[reason] ?? animal.status,
      'updatedAt': now,
    }, where: 'id = ?', whereArgs: [animal.id]);

    // Satış ise → finansa otomatik gelir
    if (reason == 'Satış' && exitPrice != null && exitPrice > 0) {
      try {
        final label = animal.name != null && animal.name!.isNotEmpty
            ? '${animal.name} (${animal.earTag})'
            : animal.earTag;
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.income,
          category: AppConstants.incomeAnimal,
          amount: exitPrice,
          date: today,
          description: 'Hayvan satışı — $label ${animal.breed}',
          relatedAnimalId: animal.id,
          notes: 'Otomatik - Sürü Modülü',
          createdAt: now,
        ));
      } catch (_) {}
    }
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('animals', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getStatusCounts() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT status, COUNT(*) as count FROM animals WHERE exitType IS NULL GROUP BY status',
    );
    return {for (var r in result) r['status'] as String: r['count'] as int};
  }

  Future<int> getTotalCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM animals WHERE exitType IS NULL');
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }
}
