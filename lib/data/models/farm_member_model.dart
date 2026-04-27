import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Çiftlik üyesi (Firestore `farms/{farmId}/members/{uid}` aynası).
///
/// Kullanıcı Yönetimi akışından eklenen tüm kullanıcılar (owner, assistant,
/// partner, vet, worker) burada görünür. Personel & Görevler modülünün
/// Personel tab'i bu veriyi kullanır.
class FarmMember {
  final String uid;
  final String farmId;
  final String displayName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime joinedAt;
  final String? invitedBy;
  final double? monthlySalary; // Kayıtlı aylık maaş (opsiyonel)
  final String? phone;         // Opsiyonel iletişim
  final String? notes;         // Opsiyonel notlar

  const FarmMember({
    required this.uid,
    required this.farmId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.joinedAt,
    this.invitedBy,
    this.monthlySalary,
    this.phone,
    this.notes,
  });

  String get roleLabel => AppConstants.roleLabels[role] ?? role;

  bool get isOwner     => role == AppConstants.roleOwner;
  bool get isAssistant => role == AppConstants.roleAssistant;
  bool get isPartner   => role == AppConstants.rolePartner;
  bool get isVet       => role == AppConstants.roleVet;
  bool get isWorker    => role == AppConstants.roleWorker;

  factory FarmMember.fromSnap(DocumentSnapshot doc, String farmId) {
    final m = doc.data() as Map<String, dynamic>;
    return FarmMember(
      uid: (m['uid'] as String?) ?? doc.id,
      farmId: farmId,
      displayName: (m['displayName'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      role: (m['role'] as String?) ?? AppConstants.roleWorker,
      isActive: (m['isActive'] as bool?) ?? true,
      joinedAt: (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invitedBy: m['invitedBy'] as String?,
      monthlySalary: (m['monthlySalary'] as num?)?.toDouble(),
      phone: m['phone'] as String?,
      notes: m['notes'] as String?,
    );
  }
}
