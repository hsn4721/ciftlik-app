import '../../core/constants/app_constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String farmId;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.farmId,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isOwner => role == AppConstants.roleOwner;
  bool get isPartner => role == AppConstants.rolePartner;
  bool get isVet => role == AppConstants.roleVet;
  bool get isWorker => role == AppConstants.roleWorker;

  bool get canManageAnimals => isOwner || isPartner;
  bool get canManageHealth => isOwner || isPartner || isVet;
  bool get canManageFinance => isOwner || isPartner;
  bool get canManageStaff => isOwner || isPartner;
  bool get canViewAll => isOwner || isPartner;

  String get roleDisplay {
    switch (role) {
      case AppConstants.roleOwner: return 'Ana Sahip';
      case AppConstants.rolePartner: return 'Ortak Sahip';
      case AppConstants.roleVet: return 'Veteriner';
      case AppConstants.roleWorker: return 'Çalışan';
      default: return role;
    }
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
    'farmId': farmId,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    uid: m['uid'] ?? '',
    email: m['email'] ?? '',
    displayName: m['displayName'] ?? '',
    role: m['role'] ?? AppConstants.roleWorker,
    farmId: m['farmId'] ?? '',
    isActive: m['isActive'] ?? true,
    createdAt: m['createdAt'] != null
        ? DateTime.tryParse(m['createdAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}
