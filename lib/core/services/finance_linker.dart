import 'package:flutter/foundation.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/finance_model.dart';
import '../constants/app_constants.dart';

/// Tüm modüllerin finans tablosuna yazarken kullandığı tek giriş noktası.
///
/// Amaçlar:
/// - Çift-yönlü senkron: Kaynak modül (ör. Aşı) silinirse buradaki kayıt da silinir.
/// - Upsert: Aynı sourceRef ile tekrar çağrı → günceller, yenisini oluşturmaz.
/// - Hata şeffaflığı: Sessiz `catch (_)` yerine debugPrint ile loglar.
class FinanceLinker {
  static final FinanceLinker instance = FinanceLinker._();
  FinanceLinker._();

  final _db = DatabaseHelper.instance;

  /// Kaynak kayda bağlı finans girişi oluşturur veya günceller.
  ///
  /// [sourceRef] 'table:id' formatında benzersiz bir anahtardır (ör. 'vaccines:45').
  /// Aynı anahtarla tekrar çağrılırsa mevcut kayıt güncellenir.
  ///
  /// Döner: etkilenen finans kaydının id'si, hata halinde null.
  Future<int?> link({
    required String source,
    required String sourceRef,
    required String type,
    required String category,
    required double amount,
    required String date,
    String? description,
    int? relatedAnimalId,
    String? invoiceNo,
    String? notes,
    String period = 'monthly',
    String paymentMethod = AppConstants.pmCash,
    bool isPaid = true,
    String? dueDate,
    double? vatRate,
  }) async {
    try {
      if (amount <= 0) {
        // Sıfır/negatif tutarlı kayıt yazma — varsa temizle.
        await unlink(sourceRef);
        return null;
      }
      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      final existing = await db.query(
        'finance',
        where: 'sourceRef = ?',
        whereArgs: [sourceRef],
        limit: 1,
      );

      final data = <String, Object?>{
        'type': type,
        'category': category,
        'amount': amount,
        'date': date,
        'description': description,
        'relatedAnimalId': relatedAnimalId,
        'invoiceNo': invoiceNo,
        'notes': notes,
        'period': period,
        'source': source,
        'sourceRef': sourceRef,
        'paymentMethod': paymentMethod,
        'isPaid': isPaid ? 1 : 0,
        'dueDate': dueDate,
        'vatRate': vatRate,
      };

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await db.update('finance', data, where: 'id = ?', whereArgs: [id]);
        return id;
      } else {
        data['createdAt'] = now;
        return await db.insert('finance', data);
      }
    } catch (e, st) {
      debugPrint('[FinanceLinker.link] $sourceRef → $e\n$st');
      return null;
    }
  }

  /// Verilen sourceRef'e bağlı finans kaydını siler.
  /// Kaynak modülde silme yapıldığında çağrılır.
  Future<void> unlink(String sourceRef) async {
    try {
      final db = await _db.database;
      await db.delete('finance', where: 'sourceRef = ?', whereArgs: [sourceRef]);
    } catch (e) {
      debugPrint('[FinanceLinker.unlink] $sourceRef → $e');
    }
  }

  /// Birden fazla sourceRef'i toplu siler (ör. stok silinince ona bağlı
  /// tüm feed_transactions kayıtlarını temizlemek için).
  Future<void> unlinkAll(Iterable<String> sourceRefs) async {
    if (sourceRefs.isEmpty) return;
    try {
      final db = await _db.database;
      final placeholders = List.filled(sourceRefs.length, '?').join(',');
      await db.delete(
        'finance',
        where: 'sourceRef IN ($placeholders)',
        whereArgs: sourceRefs.toList(),
      );
    } catch (e) {
      debugPrint('[FinanceLinker.unlinkAll] → $e');
    }
  }

  /// Prefix ile başlayan tüm kaynakları siler (ör. 'feed_transactions:123:').
  /// Dikkatli kullan: pattern geniş olursa istenmeyen kayıtları silebilir.
  Future<void> unlinkByPrefix(String prefix) async {
    try {
      final db = await _db.database;
      await db.delete(
        'finance',
        where: 'sourceRef LIKE ?',
        whereArgs: ['$prefix%'],
      );
    } catch (e) {
      debugPrint('[FinanceLinker.unlinkByPrefix] $prefix → $e');
    }
  }

  /// sourceRef ile finans kaydını getirir (varsa).
  Future<FinanceModel?> findBySourceRef(String sourceRef) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'finance',
        where: 'sourceRef = ?',
        whereArgs: [sourceRef],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FinanceModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[FinanceLinker.findBySourceRef] $sourceRef → $e');
      return null;
    }
  }

  /// Ödeme durumunu güncelle (ör. bekleyen → ödendi).
  Future<void> markPaid(int financeId, {bool paid = true}) async {
    try {
      final db = await _db.database;
      await db.update(
        'finance',
        {'isPaid': paid ? 1 : 0},
        where: 'id = ?',
        whereArgs: [financeId],
      );
    } catch (e) {
      debugPrint('[FinanceLinker.markPaid] $financeId → $e');
    }
  }

  /// Kaynağı silinmiş öksüz (orphan) finans kayıtlarını tespit eder.
  /// İleride "Ayarlar → Bakım → Orphan temizle" aracı için.
  Future<List<FinanceModel>> findOrphans() async {
    try {
      final db = await _db.database;
      // Manuel ve destek kayıtlarını atla
      final rows = await db.query(
        'finance',
        where: "source != 'manual' AND source != 'subsidy' AND sourceRef IS NOT NULL",
      );
      final orphans = <FinanceModel>[];
      for (final r in rows) {
        final ref = r['sourceRef'] as String?;
        if (ref == null || !ref.contains(':')) continue;
        final parts = ref.split(':');
        if (parts.length < 2) continue;
        final table = parts[0];
        final id = int.tryParse(parts[1]);
        if (id == null) continue;
        // Tablo var mı, kayıt var mı?
        final exists = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (exists.isEmpty) orphans.add(FinanceModel.fromMap(r));
      }
      return orphans;
    } catch (e) {
      debugPrint('[FinanceLinker.findOrphans] → $e');
      return [];
    }
  }

  /// Tüm öksüz kayıtları sil.
  Future<int> cleanOrphans() async {
    final orphans = await findOrphans();
    if (orphans.isEmpty) return 0;
    try {
      final db = await _db.database;
      final ids = orphans.map((o) => o.id).whereType<int>().toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      return await db.delete(
        'finance',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      debugPrint('[FinanceLinker.cleanOrphans] → $e');
      return 0;
    }
  }
}
