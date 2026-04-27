import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/notification_item_model.dart';

/// Çiftlik-içi bildirim paneli servisi.
/// - Vet cevapları, davet cevapları gibi olaylar buraya yazılır
/// - Owner/Assistant canlı akışla görür
/// - Kullanıcı okuduğunda kendi uid'si `readByUids`'e eklenir
/// - Okunanlar UI'da gösterilmez (filtrelenir)
class NotificationFeedService {
  NotificationFeedService._();
  static final NotificationFeedService instance = NotificationFeedService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('notifications');

  /// Yeni bildirim oluştur.
  Future<String?> create(NotificationItemModel item) async {
    try {
      final ref = await _col(item.farmId).add(item.toMap());
      return ref.id;
    } catch (e) {
      debugPrint('[NotificationFeedService.create] $e');
      return null;
    }
  }

  /// Bir çiftliğin bildirimlerini kullanıcı bazlı canlı akış.
  /// Sadece bu kullanıcının targetUids içinde olduğu kayıtlar gelir.
  Stream<List<NotificationItemModel>> streamForUser({
    required String farmId,
    required String uid,
  }) {
    return _col(farmId)
        .where('targetUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NotificationItemModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[NotificationFeedService.streamForUser] $e');
    });
  }

  /// Okundu işaretle — readByUids'e kullanıcı uid'sini ekler.
  Future<void> markAsRead({
    required String farmId,
    required String notifId,
    required String uid,
  }) async {
    try {
      await _col(farmId).doc(notifId).update({
        'readByUids': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      debugPrint('[NotificationFeedService.markAsRead] $e');
    }
  }

  /// Bir kullanıcının tüm bildirimlerini okundu işaretle.
  Future<void> markAllAsRead({
    required String farmId,
    required String uid,
  }) async {
    try {
      final snap = await _col(farmId)
          .where('targetUids', arrayContains: uid)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        final read = List<String>.from(doc.data()['readByUids'] ?? const []);
        if (!read.contains(uid)) {
          batch.update(doc.reference, {
            'readByUids': FieldValue.arrayUnion([uid]),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationFeedService.markAllAsRead] $e');
    }
  }
}
