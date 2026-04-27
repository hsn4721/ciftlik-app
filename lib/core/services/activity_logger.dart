import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/notification_item_model.dart';
import 'auth_service.dart';
import 'notification_feed_service.dart';

/// Çiftlik aktivite günlüğü.
/// Personel/Vet/Worker rollerinin önemli işlemleri loglanır → Ana Sahip + Yardımcı
/// hesaplarındaki bildirim panelinde anında görünür.
///
/// Self-action (kullanıcının kendi yaptığı işlem) loglanmaz — kendi yaptığı
/// işlem için bildirim almak gereksiz spam yaratır.
class ActivityLogger {
  ActivityLogger._();
  static final ActivityLogger instance = ActivityLogger._();

  final _db = FirebaseFirestore.instance;
  // Aynı session'da owner+assistant uid listesini cache'le (her log için Firestore okumayalım)
  final Map<String, List<String>> _managerCache = {};

  /// Bir aktiviteyi loglar.
  ///
  /// [icon] ve [color] gelecekte UI özelleştirme için meta'da saklanır.
  Future<void> log({
    required String actionType,
    required String description,
    String? relatedRef,
    Map<String, dynamic>? extra,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null || user.activeFarmId == null) return;
    final farmId = user.activeFarmId!;

    try {
      // Hedef: bu çiftliğin owner + assistant'ları (self hariç)
      final managers = await _getManagerUids(farmId);
      final targets = managers.where((u) => u != user.uid).toList();
      if (targets.isEmpty) return;

      final item = NotificationItemModel(
        farmId: farmId,
        type: NotificationType.activity,
        title: user.displayName,
        body: description,
        targetUids: targets,
        readByUids: const [],
        createdAt: DateTime.now(),
        relatedRef: relatedRef,
        meta: {
          'actionType': actionType,
          'actorUid': user.uid,
          if (extra != null) ...extra,
        },
      );
      await NotificationFeedService.instance.create(item);
    } catch (e) {
      // Sessiz hata — log başarısız olursa ana iş etkilenmesin.
      debugPrint('[ActivityLogger.log] $actionType — $e');
    }
  }

  Future<List<String>> _getManagerUids(String farmId) async {
    final cached = _managerCache[farmId];
    if (cached != null) return cached;
    try {
      final snap = await _db
          .collection('farms')
          .doc(farmId)
          .collection('members')
          .where('role', whereIn: ['owner', 'assistant', 'partner'])
          .where('isActive', isEqualTo: true)
          .get();
      final uids = snap.docs
          .map((d) => (d.data()['uid'] ?? d.id).toString())
          .toList();
      _managerCache[farmId] = uids;
      return uids;
    } catch (e) {
      debugPrint('[ActivityLogger._getManagerUids] $e');
      return const [];
    }
  }

  /// Üye listesi değişikliğinde cache'i temizle (kullanıcı eklendi/çıkarıldı sonrası).
  void invalidateCache(String farmId) => _managerCache.remove(farmId);
}
