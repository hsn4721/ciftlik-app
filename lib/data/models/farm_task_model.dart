import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Çiftlik görevi.
/// Firestore: `farms/{farmId}/tasks/{id}`
///
/// Ana Sahip / Yardımcı oluşturur, personele atar. Personel kendi atanan
/// görevlerini görür, "Tamamlandı" olarak işaretleyebilir. Tamamlanma anında
/// Ana Sahip + Yardımcı bildirim alır.
class FarmTask {
  final String? id;
  final String farmId;
  final String title;
  final String? description;
  final String assignedToUid;
  final String assignedToName;     // önbellekli — gösterim için
  final String assignedByUid;
  final String assignedByName;     // önbellekli
  final DateTime? dueDate;
  final String priority;            // AppConstants.taskPriorityXxx
  final String status;              // AppConstants.taskStatusXxx
  final String? completionNote;     // Personel tamamlama notu
  final DateTime createdAt;
  final DateTime? completedAt;

  const FarmTask({
    this.id,
    required this.farmId,
    required this.title,
    this.description,
    required this.assignedToUid,
    required this.assignedToName,
    required this.assignedByUid,
    required this.assignedByName,
    this.dueDate,
    required this.priority,
    required this.status,
    this.completionNote,
    required this.createdAt,
    this.completedAt,
  });

  bool get isPending    => status == AppConstants.taskStatusPending;
  bool get isInProgress => status == AppConstants.taskStatusInProgress;
  bool get isCompleted  => status == AppConstants.taskStatusCompleted;
  bool get isCancelled  => status == AppConstants.taskStatusCancelled;
  bool get isActive     => isPending || isInProgress;

  String get priorityLabel => AppConstants.taskPriorityLabels[priority] ?? priority;
  String get statusLabel   => AppConstants.taskStatusLabels[status] ?? status;

  bool get isOverdue =>
      dueDate != null &&
      isActive &&
      DateTime.now().isAfter(DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 23, 59, 59));

  Map<String, dynamic> toMap() => {
        'farmId': farmId,
        'title': title,
        'description': description,
        'assignedToUid': assignedToUid,
        'assignedToName': assignedToName,
        'assignedByUid': assignedByUid,
        'assignedByName': assignedByName,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'priority': priority,
        'status': status,
        'completionNote': completionNote,
        'createdAt': Timestamp.fromDate(createdAt),
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  factory FarmTask.fromSnap(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return FarmTask(
      id: doc.id,
      farmId: m['farmId'] ?? '',
      title: m['title'] ?? '',
      description: m['description'] as String?,
      assignedToUid: m['assignedToUid'] ?? '',
      assignedToName: m['assignedToName'] ?? '',
      assignedByUid: m['assignedByUid'] ?? '',
      assignedByName: m['assignedByName'] ?? '',
      dueDate: (m['dueDate'] as Timestamp?)?.toDate(),
      priority: m['priority'] ?? AppConstants.taskPriorityNormal,
      status: m['status'] ?? AppConstants.taskStatusPending,
      completionNote: m['completionNote'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (m['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
