import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Personel izin talebi.
/// Firestore: `farms/{farmId}/leave_requests/{id}`
///
/// Personel/Vet oluşturur, Ana Sahip + Yardımcı onay/red verir.
class LeaveRequest {
  final String? id;
  final String farmId;
  final String staffUid;
  final String staffName;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;        // AppConstants.leaveReasons içinden
  final String? notes;        // ek açıklama
  final String status;        // AppConstants.leaveStatusXxx
  final String? respondedByUid;
  final String? respondedByName;
  final String? responseNote;  // onay/red gerekçesi
  final DateTime createdAt;
  final DateTime? respondedAt;

  const LeaveRequest({
    this.id,
    required this.farmId,
    required this.staffUid,
    required this.staffName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.notes,
    required this.status,
    this.respondedByUid,
    this.respondedByName,
    this.responseNote,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending  => status == AppConstants.leaveStatusPending;
  bool get isApproved => status == AppConstants.leaveStatusApproved;
  bool get isRejected => status == AppConstants.leaveStatusRejected;

  String get statusLabel => AppConstants.leaveStatusLabels[status] ?? status;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() => {
        'farmId': farmId,
        'staffUid': staffUid,
        'staffName': staffName,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reason': reason,
        'notes': notes,
        'status': status,
        'respondedByUid': respondedByUid,
        'respondedByName': respondedByName,
        'responseNote': responseNote,
        'createdAt': Timestamp.fromDate(createdAt),
        'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      };

  factory LeaveRequest.fromSnap(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      farmId: m['farmId'] ?? '',
      staffUid: m['staffUid'] ?? '',
      staffName: m['staffName'] ?? '',
      startDate: (m['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (m['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: m['reason'] ?? 'Diğer',
      notes: m['notes'] as String?,
      status: m['status'] ?? AppConstants.leaveStatusPending,
      respondedByUid: m['respondedByUid'] as String?,
      respondedByName: m['respondedByName'] as String?,
      responseNote: m['responseNote'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (m['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
