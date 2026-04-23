import '../local/database_helper.dart';
import '../models/staff_model.dart';

class StaffRepository {
  final _db = DatabaseHelper.instance;

  Future<int> insertStaff(StaffModel s) async {
    final db = await _db.database;
    return await db.insert('staff', s.toMap()..remove('id'));
  }

  Future<List<StaffModel>> getAllStaff() async {
    final db = await _db.database;
    final maps = await db.query('staff', orderBy: 'name ASC');
    return maps.map((e) => StaffModel.fromMap(e)).toList();
  }

  Future<List<StaffModel>> getActiveStaff() async {
    final db = await _db.database;
    final maps = await db.query('staff', where: 'isActive = 1', orderBy: 'name ASC');
    return maps.map((e) => StaffModel.fromMap(e)).toList();
  }

  Future<int> updateStaff(StaffModel s) async {
    final db = await _db.database;
    return await db.update('staff', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteStaff(int id) async {
    final db = await _db.database;
    return await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertTask(TaskModel t) async {
    final db = await _db.database;
    return await db.insert('tasks', t.toMap()..remove('id'));
  }

  Future<List<TaskModel>> getAllTasks() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT t.*, s.name as staffName FROM tasks t
      LEFT JOIN staff s ON t.assignedToId = s.id
      ORDER BY t.isCompleted ASC, t.dueDate ASC
    ''');
    return maps.map((e) => TaskModel.fromMap(e)).toList();
  }

  Future<int> toggleTask(int id, bool completed) async {
    final db = await _db.database;
    return await db.update('tasks', {'isCompleted': completed ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await _db.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
