import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Veteriner talep modeli.
/// Ana Sahip / Yardımcı → Veteriner yönlendirilir, Veteriner sadece "okundu" işaretler.
class VetRequestModel {
  final String? id;
  final String farmId;
  final String farmName;
  final String requesterId;
  final String requesterName;
  final String vetId;
  final String vetName;
  final String category; // AppConstants.vetCatXxx
  final String reason;
  final String urgency; // AppConstants.urgencyXxx
  final String? animalTag; // opsiyonel
  final String? notes;      // opsiyonel
  final DateTime createdAt;
  final DateTime? readAt;   // vet açınca dolar

  const VetRequestModel({
    this.id,
    required this.farmId,
    required this.farmName,
    required this.requesterId,
    required this.requesterName,
    required this.vetId,
    required this.vetName,
    required this.category,
    required this.reason,
    required this.urgency,
    this.animalTag,
    this.notes,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  String get categoryLabel => AppConstants.vetRequestCategories[category] ?? category;
  String get urgencyLabel  => AppConstants.urgencyLabels[urgency] ?? urgency;

  Map<String, dynamic> toMap() => {
        'farmId': farmId,
        'farmName': farmName,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'vetId': vetId,
        'vetName': vetName,
        'category': category,
        'reason': reason,
        'urgency': urgency,
        'animalTag': animalTag,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      };

  factory VetRequestModel.fromSnap(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return VetRequestModel(
      id: doc.id,
      farmId: m['farmId'] ?? '',
      farmName: m['farmName'] ?? '',
      requesterId: m['requesterId'] ?? '',
      requesterName: m['requesterName'] ?? '',
      vetId: m['vetId'] ?? '',
      vetName: m['vetName'] ?? '',
      category: m['category'] ?? AppConstants.vetCatOther,
      reason: m['reason'] ?? '',
      urgency: m['urgency'] ?? AppConstants.urgencyNormal,
      animalTag: m['animalTag'] as String?,
      notes: m['notes'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (m['readAt'] as Timestamp?)?.toDate(),
    );
  }
}
