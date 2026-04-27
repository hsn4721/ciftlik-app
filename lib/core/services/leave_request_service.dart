import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/models/notification_item_model.dart';
import '../constants/app_constants.dart';
import 'notification_feed_service.dart';

/// Personel izin talebi yönetim servisi.
class LeaveRequestService {
  LeaveRequestService._();
  static final LeaveRequestService instance = LeaveRequestService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('leave_requests');

  /// Personel/Vet yeni izin talebi oluşturur.
  Future<String?> create(LeaveRequest req) async {
    try {
      final ref = await _col(req.farmId).add(req.toMap());
      return ref.id;
    } catch (e) {
      debugPrint('[LeaveRequestService.create] $e');
      return null;
    }
  }

  /// Çiftliğin tüm izin talepleri (owner/assistant gözlem).
  Stream<List<LeaveRequest>> streamAllForFarm(String farmId) {
    return _col(farmId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LeaveRequest.fromSnap).toList())
        .handleError((e) => debugPrint('[LeaveRequestService.streamAll] $e'));
  }

  /// Personelin kendi izin talepleri.
  Stream<List<LeaveRequest>> streamForStaff({
    required String farmId,
    required String staffUid,
  }) {
    return _col(farmId)
        .where('staffUid', isEqualTo: staffUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LeaveRequest.fromSnap).toList())
        .handleError((e) => debugPrint('[LeaveRequestService.streamForStaff] $e'));
  }

  /// Owner/Assistant izin talebine cevap verir. Personelin bildirim paneline
  /// onay/red bildirimi yazılır.
  /// Başarılıysa null, başarısızsa kullanıcıya gösterilecek hata mesajı döner.
  Future<String?> respond({
    required String farmId,
    required String requestId,
    required bool approved,
    required String respondedByUid,
    required String respondedByName,
    String? responseNote,
  }) async {
    try {
      await _col(farmId).doc(requestId).update({
        'status': approved
            ? AppConstants.leaveStatusApproved
            : AppConstants.leaveStatusRejected,
        'respondedByUid': respondedByUid,
        'respondedByName': respondedByName,
        'responseNote': responseNote,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Personelin bildirim paneline yansıt (best-effort)
      try {
        final reqDoc = await _col(farmId).doc(requestId).get();
        final data = reqDoc.data();
        if (data != null) {
          final staffUid = data['staffUid'] as String?;
          final reason = (data['reason'] as String?) ?? '';
          final dayCount = (data['dayCount'] as num?)?.toInt() ?? 0;
          if (staffUid != null && staffUid.isNotEmpty) {
            await NotificationFeedService.instance.create(NotificationItemModel(
              farmId: farmId,
              type: NotificationType.activity,
              title: approved
                  ? 'İzin talebiniz onaylandı'
                  : 'İzin talebiniz reddedildi',
              body: '$dayCount günlük "$reason" talebi · '
                  '${approved ? 'Onaylayan' : 'Reddeden'}: $respondedByName'
                  '${responseNote != null && responseNote.isNotEmpty ? ' — $responseNote' : ''}',
              targetUids: [staffUid],
              readByUids: const [],
              createdAt: DateTime.now(),
              relatedRef: 'leave_requests/$requestId',
              meta: {
                'actionType': approved ? 'leave_approved' : 'leave_rejected',
                'requestId': requestId,
              },
            ));
          }
        }
      } catch (e) {
        debugPrint('[LeaveRequestService.respond] notif feed: $e');
      }

      return null;
    } catch (e) {
      debugPrint('[LeaveRequestService.respond] $e');
      return 'İzin yanıtı kaydedilemedi: $e';
    }
  }

  /// Personel kendi pending talebini iptal etmek için silebilir.
  /// Başarılıysa null, başarısızsa hata mesajı döner.
  Future<String?> delete({required String farmId, required String requestId}) async {
    try {
      await _col(farmId).doc(requestId).delete();
      return null;
    } catch (e) {
      debugPrint('[LeaveRequestService.delete] $e');
      return 'İzin talebi silinemedi: $e';
    }
  }
}
