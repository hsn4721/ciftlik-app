import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_feed_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/notification_item_model.dart';
import '../../data/models/vet_request_model.dart';
import '../vet_request/vet_request_detail_screen.dart';

/// Bildirim paneli — okunmuş + okunmamış tüm bildirimler liste halinde.
///
/// Owner/Assistant için: `farms/{activeFarmId}/notifications` kayıtları
/// (vet okundu, davet cevap, aktivite log).
///
/// Vet için ([vetMode]=true): tüm çiftliklerden gelen `vet_requests`.
class NotificationsPanelScreen extends StatelessWidget {
  final bool vetMode;

  const NotificationsPanelScreen({super.key, this.vetMode = false});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Oturum açılmamış')));
    }

    final isVet = vetMode || user.isVet;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (!isVet)
            TextButton(
              onPressed: () async {
                final farmId = user.activeFarmId;
                if (farmId == null) return;
                await NotificationFeedService.instance
                    .markAllAsRead(farmId: farmId, uid: user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tüm bildirimler okundu olarak işaretlendi'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text(
                'Tümünü Okundu',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: isVet ? _VetNotificationsBody(uid: user.uid)
                  : _FarmNotificationsBody(
                      farmId: user.activeFarmId ?? '',
                      uid: user.uid,
                    ),
    );
  }
}

// ─── Owner / Assistant body ──────────────────────────────────────────────

class _FarmNotificationsBody extends StatelessWidget {
  final String farmId;
  final String uid;
  const _FarmNotificationsBody({required this.farmId, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (farmId.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_off_outlined,
        message: 'Aktif çiftlik seçilmemiş',
      );
    }
    return StreamBuilder<List<NotificationItemModel>>(
      stream: NotificationFeedService.instance
          .streamForUser(farmId: farmId, uid: uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            message: 'Henüz bildirim yok',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final n = items[i];
            final isRead = n.isReadBy(uid);
            return _FarmNotifTile(
              notif: n,
              isRead: isRead,
              onTap: () async {
                if (!isRead && n.id != null) {
                  await NotificationFeedService.instance.markAsRead(
                    farmId: farmId,
                    notifId: n.id!,
                    uid: uid,
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _FarmNotifTile extends StatelessWidget {
  final NotificationItemModel notif;
  final bool isRead;
  final VoidCallback onTap;
  const _FarmNotifTile({
    required this.notif,
    required this.isRead,
    required this.onTap,
  });

  /// İkon seçimi — `meta.actionType` varsa onu öncelikle kullan, yoksa type.
  IconData _iconFor(NotificationItemModel n) {
    final action = n.meta?['actionType'] as String?;
    switch (action) {
      case 'task_assigned':   return Icons.assignment_outlined;
      case 'task_completed':  return Icons.task_alt;
      case 'leave_approved':  return Icons.event_available;
      case 'leave_rejected':  return Icons.event_busy;
    }
    switch (n.type) {
      case NotificationType.vetRead:            return Icons.medical_services_outlined;
      case NotificationType.invitationAccepted: return Icons.check_circle_outline;
      case NotificationType.invitationRejected: return Icons.cancel_outlined;
      default:                                  return Icons.info_outline;
    }
  }

  Color _colorFor(NotificationItemModel n) {
    final action = n.meta?['actionType'] as String?;
    switch (action) {
      case 'task_assigned':   return AppColors.infoBlue;
      case 'task_completed':  return AppColors.primaryGreen;
      case 'leave_approved':  return AppColors.primaryGreen;
      case 'leave_rejected':  return AppColors.errorRed;
    }
    switch (n.type) {
      case NotificationType.vetRead:            return AppColors.infoBlue;
      case NotificationType.invitationAccepted: return AppColors.primaryGreen;
      case NotificationType.invitationRejected: return AppColors.errorRed;
      default:                                  return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _colorFor(notif);
    return Material(
      color: isRead ? Colors.white : iconColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? AppColors.divider : iconColor.withValues(alpha: 0.4),
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFor(notif), color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? AppColors.textGrey : AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(notif.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vet body ────────────────────────────────────────────────────────────

class _VetNotificationsBody extends StatelessWidget {
  final String uid;
  const _VetNotificationsBody({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VetRequestModel>>(
      stream: VetRequestService.instance.streamAllForVet(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            message: 'Henüz vet talebi yok',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = items[i];
            return _VetNotifTile(
              req: r,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VetRequestDetailScreen(req: r, asVet: true),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VetNotifTile extends StatelessWidget {
  final VetRequestModel req;
  final VoidCallback onTap;
  const _VetNotifTile({required this.req, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = req.isRead;
    final urgencyColor = _urgencyColor(req.urgency);
    return Material(
      color: isRead ? Colors.white : urgencyColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? AppColors.divider : urgencyColor.withValues(alpha: 0.5),
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medical_services, color: urgencyColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${req.farmName} • ${req.requesterName}',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${req.categoryLabel} — ${req.urgencyLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: urgencyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? AppColors.textGrey : AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(req.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _urgencyColor(String u) {
    if (u == 'urgent' || u == 'high') return AppColors.errorRed;
    if (u == 'low') return AppColors.primaryGreen;
    return AppColors.gold;
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
