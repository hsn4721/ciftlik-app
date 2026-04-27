import '../local/database_helper.dart';
import '../models/feed_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activity_logger.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/finance_linker.dart';

class FeedRepository {
  final _db = DatabaseHelper.instance;
  final _linker = FinanceLinker.instance;

  // ─── Stok ────────────────────────────────────────────────────────────────

  Future<int> insertStock(FeedStockModel f) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final today = now.split('T').first;
    int resultId;

    // Aynı isimde stok varsa miktarı üstüne ekle
    final existing = await db.query('feed_stock',
        where: 'LOWER(name) = LOWER(?)', whereArgs: [f.name.trim()]);
    if (existing.isNotEmpty) {
      resultId = existing.first['id'] as int;
      final currentQty = (existing.first['quantity'] as num).toDouble();
      await db.update('feed_stock', {
        'quantity': currentQty + f.quantity,
        'unitPrice': f.unitPrice ?? existing.first['unitPrice'],
        'minQuantity': f.minQuantity ?? existing.first['minQuantity'],
        'updatedAt': now,
      }, where: 'id = ?', whereArgs: [resultId]);
    } else {
      resultId = await db.insert('feed_stock', f.toMap()..remove('id'));
    }

    // Miktar > 0 ve birim fiyat girilmişse → finansa otomatik alım gideri.
    // Her ekleme ayrı bir satın alma olayı — sourceRef benzersiz (stockId+timestamp).
    if (f.quantity > 0 && f.unitPrice != null) {
      final total = f.quantity * f.unitPrice!;
      if (total > 0) {
        await _linker.link(
          source: AppConstants.srcFeedPurchase,
          sourceRef: 'feed_stock_add:$resultId:$now',
          type: AppConstants.expense,
          category: AppConstants.expenseFeed,
          amount: total,
          date: today,
          description: '${f.name} alımı — ${f.quantity.toStringAsFixed(1)} ${f.unit}',
          notes: 'Otomatik - Yem Modülü',
        );
      }
    }

    if (f.quantity > 0) {
      ActivityLogger.instance.log(
        actionType: AppConstants.activityFeedStockAdded,
        description: 'Yem stoğu: ${f.name} · ${f.quantity.toStringAsFixed(1)} ${f.unit} eklendi',
        relatedRef: 'feed_stock:$resultId',
      );
    }

    return resultId;
  }

  Future<List<FeedStockModel>> getAllStocks() async {
    final db = await _db.database;
    final maps = await db.query('feed_stock', orderBy: 'name ASC');
    return maps.map((e) => FeedStockModel.fromMap(e)).toList();
  }

  Future<int> updateStock(FeedStockModel f) async {
    final db = await _db.database;
    return await db.update('feed_stock', f.toMap()..remove('id'), where: 'id = ?', whereArgs: [f.id]);
  }

  Future<int> deleteStock(int id) async {
    final db = await _db.database;
    // Stoğa bağlı tüm finans kayıtlarını temizle
    await _linker.unlinkByPrefix('feed_stock_add:$id:');
    // Bu stoğa ait transaction'ların finans kayıtlarını temizle
    final txs = await db.query('feed_transactions',
        columns: ['id'], where: 'stockId = ?', whereArgs: [id]);
    final txRefs = txs.map((t) => 'feed_transactions:${t['id']}').toList();
    await _linker.unlinkAll(txRefs);

    await db.delete('feed_plans', where: 'stockId = ?', whereArgs: [id]);
    await db.delete('feed_transactions', where: 'stockId = ?', whereArgs: [id]);
    return await db.delete('feed_stock', where: 'id = ?', whereArgs: [id]);
  }

  // ─── İşlemler ────────────────────────────────────────────────────────────

  Future<int> insertTransaction(FeedTransactionModel t) async {
    final db = await _db.database;
    final map = t.toMap()..remove('id');
    final id = await db.insert('feed_transactions', map);
    final stock = await db.query('feed_stock', where: 'id = ?', whereArgs: [t.stockId]);
    if (stock.isNotEmpty) {
      final current = (stock.first['quantity'] as num).toDouble();
      final newQty = t.isEntry ? current + t.quantity : current - t.quantity;
      final finalQty = newQty < 0 ? 0.0 : newQty;
      final updateMap = {'quantity': finalQty, 'updatedAt': DateTime.now().toIso8601String()};
      if (t.isEntry && t.unitPrice != null) updateMap['unitPrice'] = t.unitPrice!;
      await db.update('feed_stock', updateMap, where: 'id = ?', whereArgs: [t.stockId]);
      final minQty = (stock.first['minQuantity'] as num?)?.toDouble() ?? 0;
      if (finalQty <= minQty && !t.isEntry) {
        await NotificationService.instance.showLowStockAlert(t.stockName);
      }
    }

    // Alım işlemi + birim fiyat → finansa otomatik gider
    if (t.isEntry && t.unitPrice != null) {
      final total = t.quantity * t.unitPrice!;
      if (total > 0) {
        await _linker.link(
          source: AppConstants.srcFeedPurchase,
          sourceRef: 'feed_transactions:$id',
          type: AppConstants.expense,
          category: AppConstants.expenseFeed,
          amount: total,
          date: t.date,
          description: '${t.stockName} alımı — ${t.quantity.toStringAsFixed(1)} ${t.unit}',
          notes: 'Otomatik - Yem Modülü',
        );
      }
    }

    return id;
  }

  Future<List<FeedTransactionModel>> getTransactionsByStock(int stockId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT ft.*, fs.name as stockName FROM feed_transactions ft
      LEFT JOIN feed_stock fs ON ft.stockId = fs.id
      WHERE ft.stockId = ? ORDER BY ft.date DESC
    ''', [stockId]);
    return maps.map((e) => FeedTransactionModel.fromMap(e)).toList();
  }

  Future<List<FeedTransactionModel>> getRecentTransactions({int limit = 50}) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT ft.*, fs.name as stockName FROM feed_transactions ft
      LEFT JOIN feed_stock fs ON ft.stockId = fs.id
      ORDER BY ft.createdAt DESC LIMIT ?
    ''', [limit]);
    return maps.map((e) => FeedTransactionModel.fromMap(e)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await _db.database;
    await _linker.unlink('feed_transactions:$id');
    return await db.delete('feed_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Yemleme Planı ───────────────────────────────────────────────────────

  Future<List<FeedPlanModel>> getPlans() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT fp.*, fs.name as stockName, fs.unit FROM feed_plans fp
      LEFT JOIN feed_stock fs ON fp.stockId = fs.id
      ORDER BY fs.name ASC
    ''');
    return maps.map((e) => FeedPlanModel.fromMap(e)).toList();
  }

  Future<void> savePlan(FeedPlanModel plan) async {
    final db = await _db.database;
    final existing = await db.query('feed_plans', where: 'stockId = ?', whereArgs: [plan.stockId]);
    if (existing.isEmpty) {
      await db.insert('feed_plans', plan.toMap()..remove('id'));
    } else {
      await db.update('feed_plans',
        {'morningAmount': plan.morningAmount, 'eveningAmount': plan.eveningAmount, 'updatedAt': plan.updatedAt},
        where: 'stockId = ?', whereArgs: [plan.stockId]);
    }
  }

  Future<void> deletePlan(int stockId) async {
    final db = await _db.database;
    await db.delete('feed_plans', where: 'stockId = ?', whereArgs: [stockId]);
  }

  // ─── Yemleme Uygulama ────────────────────────────────────────────────────

  Future<List<FeedSessionModel>> getTodaySessions() async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final maps = await db.query('feed_sessions', where: 'date = ?', whereArgs: [today]);
    return maps.map((e) => FeedSessionModel.fromMap(e)).toList();
  }

  Future<List<FeedSessionModel>> getRecentSessions({int limit = 30}) async {
    final db = await _db.database;
    final maps = await db.query('feed_sessions', orderBy: 'createdAt DESC', limit: limit);
    return maps.map((e) => FeedSessionModel.fromMap(e)).toList();
  }

  // Belirli oturum için planı uygular, stoktan düşer
  Future<String?> applyFeeding(String session) async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;

    final existing = await db.query('feed_sessions',
      where: 'date = ? AND session = ?', whereArgs: [today, session]);
    if (existing.isNotEmpty) return '$session yemi bugün zaten verildi';

    final plans = await getPlans();
    if (plans.isEmpty) return 'Önce yemleme planı oluşturun';

    final isMorning = session == 'Sabah';
    double totalCost = 0;
    final now = DateTime.now().toIso8601String();

    for (final plan in plans) {
      final amount = isMorning ? plan.morningAmount : plan.eveningAmount;
      if (amount <= 0) continue;

      final stocks = await db.query('feed_stock', where: 'id = ?', whereArgs: [plan.stockId]);
      if (stocks.isEmpty) continue;
      final stock = stocks.first;
      final currentQty = (stock['quantity'] as num).toDouble();
      final unitPrice = stock['unitPrice'] != null ? (stock['unitPrice'] as num).toDouble() : null;

      final newQty = (currentQty - amount).clamp(0.0, double.infinity);
      await db.update('feed_stock',
        {'quantity': newQty, 'updatedAt': now},
        where: 'id = ?', whereArgs: [plan.stockId]);

      await db.insert('feed_transactions', {
        'stockId': plan.stockId,
        'transactionType': '$session Yemi',
        'quantity': amount,
        'unit': plan.unit,
        'unitPrice': unitPrice,
        'date': today,
        'notes': null,
        'createdAt': now,
      });

      if (unitPrice != null) totalCost += amount * unitPrice;

      final minQty = stock['minQuantity'] != null ? (stock['minQuantity'] as num).toDouble() : 0.0;
      if (newQty <= minQty) {
        await NotificationService.instance.showLowStockAlert(plan.stockName);
      }
    }

    // Oturum kaydı
    final sessionId = await db.insert('feed_sessions', {
      'date': today,
      'session': session,
      'totalCost': totalCost > 0 ? totalCost : null,
      'notes': null,
      'createdAt': now,
    });

    // Günlük yem maliyeti → period='daily', source='feed_daily'.
    // Yeni UI bu kayıtları aylık toplamda da gösterir (çift saymadan).
    if (totalCost > 0) {
      await _linker.link(
        source: AppConstants.srcFeedDaily,
        sourceRef: 'feed_sessions:$sessionId',
        type: AppConstants.expense,
        category: AppConstants.expenseFeed,
        amount: totalCost,
        date: today,
        period: 'daily',
        description: '$session yemi — ${plans.where((p) => (isMorning ? p.morningAmount : p.eveningAmount) > 0).length} çeşit',
        notes: 'Otomatik - Yem Modülü',
      );
    }

    return null;
  }

  /// Özel miktarlarla yemleme uygula (günlük düzenleme desteği)
  Future<String?> applyFeedingWithAmounts(
    String session,
    Map<int, double> amounts,
  ) async {
    final db = await _db.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query('feed_sessions',
        where: 'date = ? AND session = ?', whereArgs: [today, session]);
    if (existing.isNotEmpty) return '$session yemi bugün zaten uygulandı';

    if (amounts.isEmpty || amounts.values.every((v) => v <= 0)) {
      return 'Verilecek yem miktarı girilmedi';
    }

    double totalCost = 0;

    for (final entry in amounts.entries) {
      final stockId = entry.key;
      final amount = entry.value;
      if (amount <= 0) continue;

      final stocks = await db.query('feed_stock', where: 'id = ?', whereArgs: [stockId]);
      if (stocks.isEmpty) continue;
      final stock = stocks.first;
      final currentQty = (stock['quantity'] as num).toDouble();
      final unitPrice = stock['unitPrice'] != null ? (stock['unitPrice'] as num).toDouble() : null;
      final unit = stock['unit'] as String;
      final stockName = stock['name'] as String;

      final newQty = (currentQty - amount).clamp(0.0, double.infinity);
      await db.update('feed_stock',
          {'quantity': newQty, 'updatedAt': now},
          where: 'id = ?', whereArgs: [stockId]);

      await db.insert('feed_transactions', {
        'stockId': stockId,
        'transactionType': '$session Yemi',
        'quantity': amount,
        'unit': unit,
        'unitPrice': unitPrice,
        'date': today,
        'notes': null,
        'createdAt': now,
      });

      if (unitPrice != null) totalCost += amount * unitPrice;

      final minQty = stock['minQuantity'] != null ? (stock['minQuantity'] as num).toDouble() : 0.0;
      if (newQty <= minQty) {
        await NotificationService.instance.showLowStockAlert(stockName);
      }
    }

    final sessionId = await db.insert('feed_sessions', {
      'date': today,
      'session': session,
      'totalCost': totalCost > 0 ? totalCost : null,
      'notes': null,
      'createdAt': now,
    });

    if (totalCost > 0) {
      await _linker.link(
        source: AppConstants.srcFeedDaily,
        sourceRef: 'feed_sessions:$sessionId',
        type: AppConstants.expense,
        category: AppConstants.expenseFeed,
        amount: totalCost,
        date: today,
        period: 'daily',
        description: '$session yemi — ${amounts.entries.where((e) => e.value > 0).length} çeşit',
        notes: 'Otomatik - Yem Modülü',
      );
    }

    return null;
  }

  // Günlük toplam yem maliyeti (plan * birim fiyat)
  Future<double> getDailyPlanCost() async {
    final db = await _db.database;
    final plans = await getPlans();
    double total = 0;
    for (final plan in plans) {
      if (plan.dailyAmount <= 0) continue;
      final stocks = await db.query('feed_stock', where: 'id = ?', whereArgs: [plan.stockId]);
      if (stocks.isNotEmpty && stocks.first['unitPrice'] != null) {
        total += plan.dailyAmount * (stocks.first['unitPrice'] as num).toDouble();
      }
    }
    return total;
  }

  // Stokların kaç günlük yem planına yeteceği
  Future<Map<int, int>> getDaysRemaining() async {
    final db = await _db.database;
    final plans = await getPlans();
    final result = <int, int>{};
    for (final plan in plans) {
      if (plan.dailyAmount <= 0) continue;
      final stocks = await db.query('feed_stock', where: 'id = ?', whereArgs: [plan.stockId]);
      if (stocks.isNotEmpty) {
        final qty = (stocks.first['quantity'] as num).toDouble();
        result[plan.stockId] = (qty / plan.dailyAmount).floor();
      }
    }
    return result;
  }
}
