import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/farm_task_model.dart';
import '../../data/models/notification_item_model.dart';
import '../constants/app_constants.dart';
import 'notification_feed_service.dart';

/// Çiftlik görev (task) yönetim servisi.
class FarmTaskService {
  FarmTaskService._();
  static final FarmTaskService instance = FarmTaskService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('tasks');

  /// Yeni görev oluştur. Atanan personele bildirim feed'inde de kayıt açılır
  /// (Worker'ın bildirim panelinde "Yeni görev: X" olarak görünür).
  Future<String?> create(FarmTask t) async {
    try {
      final ref = await _col(t.farmId).add(t.toMap());
      // Worker bildirim paneli için notification feed kaydı (best-effort).
      // Self-assignment ise bildirim oluşturma.
      if (t.assignedToUid.isNotEmpty && t.assignedToUid != t.assignedByUid) {
        final desc = t.description?.trim();
        await NotificationFeedService.instance.create(NotificationItemModel(
          farmId: t.farmId,
          type: NotificationType.activity,
          title: 'Yeni görev: ${t.title}',
          body: desc != null && desc.isNotEmpty ? desc : 'Atayan: ${t.assignedByName}',
          targetUids: [t.assignedToUid],
          readByUids: const [],
          createdAt: DateTime.now(),
          relatedRef: 'tasks/${ref.id}',
          meta: {
            'actionType': 'task_assigned',
            'priority': t.priority,
            'taskId': ref.id,
          },
        ));
      }
      return ref.id;
    } catch (e) {
      debugPrint('[FarmTaskService.create] $e');
      return null;
    }
  }

  /// Yöneticinin (owner/assistant) gördüğü tüm görevler — en yeniden eskiye.
  Stream<List<FarmTask>> streamAllForFarm(String farmId) {
    return _col(farmId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FarmTask.fromSnap).toList())
        .handleError((e) => debugPrint('[FarmTaskService.streamAll] $e'));
  }

  /// Personele atanmış görevler — kendi cihazında gösterim için.
  Stream<List<FarmTask>> streamForStaff({
    required String farmId,
    required String staffUid,
  }) {
    return _col(farmId)
        .where('assignedToUid', isEqualTo: staffUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FarmTask.fromSnap).toList())
        .handleError((e) => debugPrint('[FarmTaskService.streamForStaff] $e'));
  }

  /// Personelin status değişikliği (in_progress → completed).
  /// Başarılıysa null, başarısızsa kullanıcıya gösterilecek hata mesajı döner.
  Future<String?> updateStatus({
    required String farmId,
    required String taskId,
    required String newStatus,
    String? completionNote,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
      };
      if (newStatus == AppConstants.taskStatusCompleted) {
        updates['completedAt'] = Timestamp.fromDate(DateTime.now());
        if (completionNote != null && completionNote.isNotEmpty) {
          updates['completionNote'] = completionNote;
        }
      }
      await _col(farmId).doc(taskId).update(updates);
      return null;
    } catch (e) {
      debugPrint('[FarmTaskService.updateStatus] $e');
      return 'Görev güncellenemedi: $e';
    }
  }

  /// Görevi sil — yalnızca yönetici (owner/assistant) çağırır.
  /// Başarılıysa null, başarısızsa hata mesajı döner.
  Future<String?> delete({required String farmId, required String taskId}) async {
    try {
      await _col(farmId).doc(taskId).delete();
      return null;
    } catch (e) {
      debugPrint('[FarmTaskService.delete] $e');
      return 'Görev silinemedi: $e';
    }
  }
}
