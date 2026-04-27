import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/vet_request_model.dart';

/// Veteriner talep sistemi — Firestore tabanlı.
///
/// Koleksiyon yolu: `farms/{farmId}/vet_requests/{docId}`
///
/// Okuma/yazma yetkileri firestore.rules dosyasında tanımlıdır:
/// - Ana Sahip / Yardımcı: oluşturabilir + okuyabilir
/// - Veteriner: kendisine atanmış talepleri okuyabilir + readAt güncelleyebilir
class VetRequestService {
  VetRequestService._();
  static final VetRequestService instance = VetRequestService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('vet_requests');

  /// Yeni talep oluştur. Dönen Future: oluşturulan dokümanın id'si.
  Future<String?> createRequest(VetRequestModel req) async {
    try {
      final ref = await _col(req.farmId).add(req.toMap());
      return ref.id;
    } catch (e, st) {
      debugPrint('[VetRequestService.createRequest] $e\n$st');
      return null;
    }
  }

  /// Vet'e gelen talepler canlı akışı (tek çiftlik — en yeniden eskiye).
  Stream<List<VetRequestModel>> streamRequestsForVet({
    required String farmId,
    required String vetId,
  }) {
    return _col(farmId)
        .where('vetId', isEqualTo: vetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(VetRequestModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[VetRequestService.streamRequestsForVet] $e');
    });
  }

  /// Vet'e gelen TÜM çiftliklerdeki talepler (vet ana sayfası için).
  /// Firestore collection group query — firestore.rules + composite index gerekli.
  Stream<List<VetRequestModel>> streamAllForVet(String vetId) {
    return _db
        .collectionGroup('vet_requests')
        .where('vetId', isEqualTo: vetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(VetRequestModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[VetRequestService.streamAllForVet] $e');
    });
  }

  /// Requester'ın kendi açtığı talepler canlı akışı.
  Stream<List<VetRequestModel>> streamMyRequests({
    required String farmId,
    required String requesterId,
  }) {
    return _col(farmId)
        .where('requesterId', isEqualTo: requesterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(VetRequestModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[VetRequestService.streamMyRequests] $e');
    });
  }

  /// Talebi okundu işaretle (vet açtığında otomatik).
  Future<void> markAsRead({required String farmId, required String docId}) async {
    try {
      await _col(farmId).doc(docId).update({
        'readAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('[VetRequestService.markAsRead] $e');
    }
  }

  /// Veterineri olmayan bir okunmamış talep var mı? (vet bildirimini tetiklemek için)
  Future<int> countUnreadForVet({required String farmId, required String vetId}) async {
    try {
      final snap = await _col(farmId)
          .where('vetId', isEqualTo: vetId)
          .where('readAt', isNull: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('[VetRequestService.countUnread] $e');
      return 0;
    }
  }
}
