import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/milking_repository.dart';
import '../../data/repositories/bulk_milking_repository.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/calf_repository.dart';
import '../../data/repositories/equipment_repository.dart';
import '../../data/repositories/staff_repository.dart';

class BackupResult {
  final bool success;
  final String? error;
  final DateTime? lastBackupAt;
  const BackupResult({required this.success, this.error, this.lastBackupAt});
}

class BackupService {
  static final instance = BackupService._();
  BackupService._();

  final _db = FirebaseFirestore.instance;

  String? get _farmId => AuthService.instance.currentUser?.farmId;

  // ─── Yedekleme ────────────────────────────────────────────────────────────

  Future<BackupResult> backup({void Function(String)? onProgress}) async {
    final farmId = _farmId;
    if (farmId == null) return const BackupResult(success: false, error: 'Oturum açık değil');

    try {
      final farmRef = _db.collection('farms').doc(farmId);

      onProgress?.call('Hayvanlar yedekleniyor...');
      await _backupCollection(
        farmRef.collection('animals'),
        (await AnimalRepository().getAll()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Buzağılar yedekleniyor...');
      await _backupCollection(
        farmRef.collection('calves'),
        (await CalfRepository().getAllCalves()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Süt kayıtları yedekleniyor...');
      await _backupCollection(
        farmRef.collection('milking'),
        (await MilkingRepository().getAll()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Toplu sağım yedekleniyor...');
      await _backupCollection(
        farmRef.collection('bulk_milking'),
        (await BulkMilkingRepository().getAll(limit: 99999)).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Sağlık kayıtları yedekleniyor...');
      final healthRepo = HealthRepository();
      await _backupCollection(
        farmRef.collection('health'),
        (await healthRepo.getAllHealth()).map((e) => e.toMap()).toList(),
      );
      await _backupCollection(
        farmRef.collection('vaccines'),
        (await healthRepo.getAllVaccines()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Finans kayıtları yedekleniyor...');
      await _backupCollection(
        farmRef.collection('finance'),
        (await FinanceRepository().getAll()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Yem stokları yedekleniyor...');
      final feedRepo = FeedRepository();
      await _backupCollection(
        farmRef.collection('feed_stock'),
        (await feedRepo.getAllStocks()).map((e) => e.toMap()).toList(),
      );
      await _backupCollection(
        farmRef.collection('feed_transactions'),
        (await feedRepo.getRecentTransactions(limit: 99999)).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Ekipmanlar yedekleniyor...');
      await _backupCollection(
        farmRef.collection('equipment'),
        (await EquipmentRepository().getAll()).map((e) => e.toMap()).toList(),
      );

      onProgress?.call('Personel yedekleniyor...');
      await _backupCollection(
        farmRef.collection('staff'),
        (await StaffRepository().getAllStaff()).map((e) => e.toMap()).toList(),
      );

      // Meta bilgiyi güncelle
      final now = DateTime.now();
      await farmRef.set({
        'lastBackupAt': now.toIso8601String(),
        'backupVersion': 1,
      }, SetOptions(merge: true));

      return BackupResult(success: true, lastBackupAt: now);
    } catch (e) {
      return BackupResult(success: false, error: e.toString());
    }
  }

  // ─── Son yedekleme zamanını getir ────────────────────────────────────────

  Future<DateTime?> getLastBackupTime() async {
    final farmId = _farmId;
    if (farmId == null) return null;
    try {
      final doc = await _db.collection('farms').doc(farmId).get();
      final raw = doc.data()?['lastBackupAt'] as String?;
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  // ─── Yardımcı: koleksiyona batch yaz ────────────────────────────────────

  Future<void> _backupCollection(
    CollectionReference ref,
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;

    // Eski verileri sil
    final existing = await ref.get();
    final deleteBatches = _chunkList(existing.docs, 500);
    for (final chunk in deleteBatches) {
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Yeni verileri yaz
    final writeBatches = _chunkList(records, 500);
    for (final chunk in writeBatches) {
      final batch = _db.batch();
      for (final record in chunk) {
        final id = record['id']?.toString() ?? ref.doc().id;
        final cleanRecord = Map<String, dynamic>.from(record)
          ..removeWhere((_, v) => v == null);
        batch.set(ref.doc(id), cleanRecord);
      }
      await batch.commit();
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
