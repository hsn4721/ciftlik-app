import '../local/database_helper.dart';
import '../models/equipment_model.dart';
import '../models/finance_model.dart';
import '../../core/constants/app_constants.dart';
import 'finance_repository.dart';

class EquipmentRepository {
  final _db = DatabaseHelper.instance;
  final _financeRepo = FinanceRepository();

  Future<int> insert(EquipmentModel e) async {
    final db = await _db.database;
    final id = await db.insert('equipment', e.toMap()..remove('id'));

    if (e.purchasePrice != null && e.purchasePrice! > 0) {
      final date = e.purchaseDate != null
          ? e.purchaseDate!.toIso8601String().split('T').first
          : DateTime.now().toIso8601String().split('T').first;
      final label = e.brand != null ? '${e.name} (${e.brand})' : e.name;
      try {
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.expense,
          category: AppConstants.expenseEquipment,
          amount: e.purchasePrice!,
          date: date,
          description: 'Ekipman alımı — $label',
          notes: 'Otomatik - Ekipman Modülü',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {}
    }

    return id;
  }

  Future<List<EquipmentModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('equipment', orderBy: 'name ASC');
    return maps.map((e) => EquipmentModel.fromMap(e)).toList();
  }

  Future<int> update(EquipmentModel e) async {
    final db = await _db.database;
    return await db.update('equipment', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('equipment', where: 'id = ?', whereArgs: [id]);
  }
}
