import '../local/database_helper.dart';
import '../models/bulk_milking_model.dart';
import '../models/finance_model.dart';
import '../../core/constants/app_constants.dart';
import 'finance_repository.dart';

class TankRepository {
  final _db = DatabaseHelper.instance;
  final _financeRepo = FinanceRepository();

  Future<double> getCurrentBalance() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        'SELECT balanceAfter FROM milk_tank_log ORDER BY id DESC LIMIT 1');
    if (result.isEmpty) return 0.0;
    return (result.first['balanceAfter'] as num).toDouble();
  }

  Future<TankLogModel> _addEntry({
    required String type,
    required double amount,
    String? notes,
    String? date,
  }) async {
    final db = await _db.database;
    final current = await getCurrentBalance();
    final newBalance = (current + amount).clamp(0.0, double.infinity);
    final now = DateTime.now().toIso8601String();
    final today = date ?? now.split('T').first;

    final log = TankLogModel(
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      notes: notes,
      date: today,
      createdAt: now,
    );
    final map = log.toMap()..remove('id');
    final id = await db.insert('milk_tank_log', map);
    return TankLogModel(
      id: id,
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      notes: notes,
      date: today,
      createdAt: now,
    );
  }

  Future<void> addMilking(double amount, {String? notes, String? date}) =>
      _addEntry(type: 'Sağım', amount: amount, notes: notes, date: date);

  Future<void> addBulkMilking(double amount, {String? notes, String? date}) =>
      _addEntry(type: 'Toplu Sağım', amount: amount, notes: notes, date: date);

  Future<void> deduct(double amount, {String? notes, double? unitPrice}) async {
    await _addEntry(type: 'Satış', amount: -amount, notes: notes);
    if (unitPrice != null && unitPrice > 0) {
      final total = amount * unitPrice;
      final today = DateTime.now().toIso8601String().split('T').first;
      try {
        await _financeRepo.insert(FinanceModel(
          type: AppConstants.income,
          category: AppConstants.incomeMilk,
          amount: total,
          date: today,
          period: 'daily',
          description: 'Süt satışı — ${amount.toStringAsFixed(1)} L × ₺${unitPrice.toStringAsFixed(2)}',
          notes: notes != null && notes.isNotEmpty ? notes : 'Otomatik - Süt Modülü',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } catch (_) {}
    }
  }

  Future<void> resetTank({String? notes}) async {
    final current = await getCurrentBalance();
    if (current <= 0) return;
    await _addEntry(type: 'Sıfırlama', amount: -current, notes: notes ?? 'Tank sıfırlandı');
  }

  Future<List<TankLogModel>> getLogs({int limit = 50}) async {
    final db = await _db.database;
    final maps = await db.query('milk_tank_log',
        orderBy: 'id DESC', limit: limit);
    return maps.map((e) => TankLogModel.fromMap(e)).toList();
  }
}
