import 'package:cloud_firestore/cloud_firestore.dart';

/// Bekleyen/işlenmiş çiftlik daveti.
///
/// Firestore yolu: `invitations/{inviteId}` (top-level).
/// Email bazlı eşleşme ile çalışır. Vet kayıt olduğunda/girdiğinde
/// kendi email'ine gelen davetleri görür ve kabul edebilir.
class InvitationStatus {
  InvitationStatus._();
  static const pending  = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const expired  = 'expired';
  static const cancelled = 'cancelled'; // Owner davetiyi geri aldı
}

class InvitationModel {
  final String? id;
  final String email;           // Hedef kullanıcının email'i (lowercase)
  final String farmId;
  final String farmName;
  final String role;            // assistant / partner / vet / worker
  final String invitedBy;       // Davet eden kullanıcının uid'i
  final String invitedByName;   // Önbellekli
  final DateTime createdAt;
  final String status;          // InvitationStatus.xxx
  final DateTime? respondedAt;  // kabul/red tarihi

  const InvitationModel({
    this.id,
    required this.email,
    required this.farmId,
    required this.farmName,
    required this.role,
    required this.invitedBy,
    required this.invitedByName,
    required this.createdAt,
    required this.status,
    this.respondedAt,
  });

  bool get isPending => status == InvitationStatus.pending;

  Map<String, dynamic> toMap() => {
        'email': email.toLowerCase(),
        'farmId': farmId,
        'farmName': farmName,
        'role': role,
        'invitedBy': invitedBy,
        'invitedByName': invitedByName,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
        if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      };

  factory InvitationModel.fromSnap(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return InvitationModel(
      id: doc.id,
      email: (m['email'] ?? '').toString().toLowerCase(),
      farmId: m['farmId'] ?? '',
      farmName: m['farmName'] ?? '',
      role: m['role'] ?? 'worker',
      invitedBy: m['invitedBy'] ?? '',
      invitedByName: m['invitedByName'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: m['status'] ?? InvitationStatus.pending,
      respondedAt: (m['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
