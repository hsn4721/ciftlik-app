import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../core/services/notification_feed_service.dart';
import '../../data/models/vet_request_model.dart';
import '../../data/models/notification_item_model.dart';

/// Veteriner talep detayı. Vet açtığında otomatik "okundu" işaretlenir.
class VetRequestDetailScreen extends StatefulWidget {
  final VetRequestModel req;
  final bool asVet;
  const VetRequestDetailScreen({super.key, required this.req, required this.asVet});

  @override
  State<VetRequestDetailScreen> createState() => _VetRequestDetailScreenState();
}

class _VetRequestDetailScreenState extends State<VetRequestDetailScreen> {
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    _maybeMarkRead();
  }

  Future<void> _maybeMarkRead() async {
    // Vet, kendisine gelen okunmamış talebi açınca otomatik işaretle.
    if (!widget.asVet) return;
    if (widget.req.isRead) return;
    final user = AuthService.instance.currentUser;
    if (user == null || user.uid != widget.req.vetId) return;
    if (widget.req.id == null) return;

    setState(() => _markingRead = true);
    await VetRequestService.instance.markAsRead(
      farmId: widget.req.farmId,
      docId: widget.req.id!,
    );

    // Çiftlik bildirim paneline yaz (owner/assistant feed'inde görünsün)
    try {
      final notif = NotificationItemModel(
        farmId: widget.req.farmId,
        type: NotificationType.vetRead,
        title: 'Veteriner Talebinizi Gördü',
        body: '${user.displayName} "${widget.req.reason}" talebinizi okudu',
        targetUids: [widget.req.requesterId],
        readByUids: const [],
        createdAt: DateTime.now(),
        relatedRef: 'vet_requests/${widget.req.id}',
      );
      await NotificationFeedService.instance.create(notif);
    } catch (_) {}

    if (mounted) setState(() => _markingRead = false);
  }

  Color get _urgencyColor {
    switch (widget.req.urgency) {
      case AppConstants.urgencyCritical: return AppColors.errorRed;
      case AppConstants.urgencyHigh:     return AppColors.gold;
      default:                           return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    final timeFmt = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Talep Detayı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aciliyet rozeti + başlık
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_urgencyColor, _urgencyColor.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r.urgencyLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r.categoryLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(r.reason,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bilgi kartı
          _Card(title: 'Talep Bilgisi', items: [
            _Row(icon: Icons.agriculture, label: 'Çiftlik', value: r.farmName),
            _Row(icon: Icons.person_outline, label: 'Gönderen', value: r.requesterName),
            _Row(icon: Icons.medical_services, label: 'Veteriner', value: r.vetName),
            _Row(icon: Icons.schedule, label: 'Tarih', value: timeFmt.format(r.createdAt)),
            if (r.animalTag != null)
              _Row(icon: Icons.tag, label: 'Hayvan Küpe', value: r.animalTag!),
          ]),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(title: 'Ek Not', items: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(r.notes!, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ], raw: true),
          ],
          const SizedBox(height: 16),
          // Okundu durumu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: r.isRead
                  ? AppColors.infoBlue.withValues(alpha: 0.08)
                  : AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (r.isRead ? AppColors.infoBlue : AppColors.gold).withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              if (_markingRead)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
              else
                Icon(
                  r.isRead ? Icons.done_all : Icons.schedule,
                  color: r.isRead ? AppColors.infoBlue : AppColors.gold,
                  size: 18,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.isRead ? 'Veteriner talebi gördü' : 'Veteriner henüz görmedi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: r.isRead ? AppColors.infoBlue : AppColors.gold,
                      ),
                    ),
                    if (r.isRead)
                      Text(timeFmt.format(r.readAt!),
                          style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Bilgilendirme kutusu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.textGrey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textGrey),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Bu sistem tek yönlüdür — veteriner talebe cevap veremez, yalnızca okundu bilgisi iletilir.',
                style: TextStyle(fontSize: 11, color: AppColors.textGrey, height: 1.4),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final bool raw;
  const _Card({required this.title, required this.items, this.raw = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
          ),
          if (!raw) const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        const SizedBox(width: 10),
        Text('$label:',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }
}
