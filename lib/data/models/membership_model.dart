import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcının bir çiftlikteki üyeliği.
///
/// Firestore yolu: `users/{uid}/memberships/{farmId}`
/// Aynı zamanda ayna olarak: `farms/{farmId}/members/{uid}`
///
/// Aynı kullanıcı birden fazla çiftliğin üyesi olabilir (ör. veteriner
/// 5 farklı çiftliğe hizmet verir). Her üyelikte rol ayrıdır.
class MembershipModel {
  final String farmId;
  final String farmName;       // Önbellekli — hızlı görüntü için
  final String role;           // owner / assistant / partner / vet / worker
  final bool isActive;
  final String? invitedBy;     // Daveti yapan kullanıcının uid'i (yok varsa null = owner olarak kurdu)
  final DateTime joinedAt;

  const MembershipModel({
    required this.farmId,
    required this.farmName,
    required this.role,
    required this.isActive,
    required this.joinedAt,
    this.invitedBy,
  });

  Map<String, dynamic> toMap() => {
        'farmId': farmId,
        'farmName': farmName,
        'role': role,
        'isActive': isActive,
        'invitedBy': invitedBy,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };

  factory MembershipModel.fromMap(Map<String, dynamic> m) => MembershipModel(
        farmId: m['farmId'] ?? '',
        farmName: m['farmName'] ?? '',
        role: m['role'] ?? 'worker',
        isActive: m['isActive'] ?? true,
        invitedBy: m['invitedBy'] as String?,
        joinedAt: (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  MembershipModel copyWith({
    String? farmId,
    String? farmName,
    String? role,
    bool? isActive,
    String? invitedBy,
    DateTime? joinedAt,
  }) =>
      MembershipModel(
        farmId: farmId ?? this.farmId,
        farmName: farmName ?? this.farmName,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        invitedBy: invitedBy ?? this.invitedBy,
        joinedAt: joinedAt ?? this.joinedAt,
      );
}
