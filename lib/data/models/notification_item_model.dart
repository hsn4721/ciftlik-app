import 'package:cloud_firestore/cloud_firestore.dart';

/// Çiftlik-içi bildirim paneli öğesi.
/// Firestore: `farms/{farmId}/notifications/{id}`
///
/// Owner/Assistant için vet cevapları, davet cevapları, diğer aktiviteler
/// tek panelde gösterilir. `readByUids` ile birden fazla kullanıcı aynı
/// bildirimi bağımsız "okundu" işaretleyebilir.
class NotificationType {
  NotificationType._();
  static const vetRead            = 'vet_read';          // Vet talebi okudu
  static const invitationAccepted = 'invite_accepted';   // Davet kabul
  static const invitationRejected = 'invite_rejected';   // Davet red
  static const activity            = 'activity';          // Genel aktivite (gelecek faz)
}

class NotificationItemModel {
  final String? id;
  final String farmId;
  final String type;
  final String title;
  final String body;
  final List<String> targetUids;   // Bu bildirimi görecek kullanıcılar
  final List<String> readByUids;   // Okuyanlar
  final DateTime createdAt;
  final String? relatedRef;        // ilişkili doküman (örn. 'invitations/xyz')
  final Map<String, dynamic>? meta;

  const NotificationItemModel({
    this.id,
    required this.farmId,
    required this.type,
    required this.title,
    required this.body,
    required this.targetUids,
    required this.readByUids,
    required this.createdAt,
    this.relatedRef,
    this.meta,
  });

  bool isReadBy(String uid) => readByUids.contains(uid);

  Map<String, dynamic> toMap() => {
        'farmId': farmId,
        'type': type,
        'title': title,
        'body': body,
        'targetUids': targetUids,
        'readByUids': readByUids,
        'createdAt': Timestamp.fromDate(createdAt),
        if (relatedRef != null) 'relatedRef': relatedRef,
        if (meta != null) 'meta': meta,
      };

  factory NotificationItemModel.fromSnap(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return NotificationItemModel(
      id: doc.id,
      farmId: m['farmId'] ?? '',
      type: m['type'] ?? 'activity',
      title: m['title'] ?? '',
      body: m['body'] ?? '',
      targetUids: List<String>.from(m['targetUids'] ?? const []),
      readByUids: List<String>.from(m['readByUids'] ?? const []),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedRef: m['relatedRef'] as String?,
      meta: (m['meta'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
