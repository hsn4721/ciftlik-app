import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/invitation_model.dart';

/// Bekleyen çiftlik davetlerini dinleyen ve yöneten servis.
/// Aktif kullanıcı kendi email'ine gelen bekleyen davetleri canlı görür.
class InvitationService {
  InvitationService._();
  static final InvitationService instance = InvitationService._();

  final _db = FirebaseFirestore.instance;

  /// Bir email için bekleyen davetler (canlı akış).
  Stream<List<InvitationModel>> streamPendingForEmail(String email) {
    final lc = email.trim().toLowerCase();
    return _db
        .collection('invitations')
        .where('email', isEqualTo: lc)
        .where('status', isEqualTo: InvitationStatus.pending)
        .snapshots()
        .map((snap) => snap.docs.map(InvitationModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[InvitationService.streamPending] $e');
    });
  }

  /// Belirli çiftlik için tüm davet geçmişi (owner görüntüler).
  Stream<List<InvitationModel>> streamFarmInvitations(String farmId) {
    return _db
        .collection('invitations')
        .where('farmId', isEqualTo: farmId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(InvitationModel.fromSnap).toList())
        .handleError((e) {
      debugPrint('[InvitationService.streamFarmInvitations] $e');
    });
  }

  /// Owner davet iptal eder (hâlâ pending ise).
  Future<void> cancelInvitation(String inviteId) async {
    try {
      await _db.collection('invitations').doc(inviteId).update({
        'status': InvitationStatus.cancelled,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('[InvitationService.cancel] $e');
    }
  }
}
