import '../local/database_helper.dart';
import '../models/equipment_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/finance_linker.dart';

class EquipmentRepository {
  final _db = DatabaseHelper.instance;
  final _linker = FinanceLinker.instance;

  Future<int> insert(EquipmentModel e) async {
    final db = await _db.database;
    final id = await db.insert('equipment', e.toMap()..remove('id'));
    await _syncFinance(e.copyWith(id: id));
    return id;
  }

  Future<List<EquipmentModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('equipment', orderBy: 'name ASC');
    return maps.map((e) => EquipmentModel.fromMap(e)).toList();
  }

  Future<int> update(EquipmentModel e) async {
    final db = await _db.database;
    final rows = await db.update('equipment', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    await _syncFinance(e);
    return rows;
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    await _linker.unlink('equipment:$id');
    return await db.delete('equipment', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _syncFinance(EquipmentModel e) async {
    final ref = 'equipment:${e.id}';
    if (e.purchasePrice == null || e.purchasePrice! <= 0) {
      await _linker.unlink(ref);
      return;
    }
    final date = e.purchaseDate != null
        ? e.purchaseDate!.toIso8601String().split('T').first
        : DateTime.now().toIso8601String().split('T').first;
    final label = e.brand != null ? '${e.name} (${e.brand})' : e.name;
    await _linker.link(
      source: AppConstants.srcEquipment,
      sourceRef: ref,
      type: AppConstants.expense,
      category: AppConstants.expenseEquipment,
      amount: e.purchasePrice!,
      date: date,
      description: 'Ekipman alımı — $label',
      notes: 'Otomatik - Ekipman Modülü',
    );
  }
}
