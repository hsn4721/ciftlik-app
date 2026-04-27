import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_feed_service.dart';
import '../../core/services/vet_request_service.dart';
import '../../core/theme/app_theme.dart';
import 'notifications_panel_screen.dart';

/// AppBar'da ayarlar çarkı yanına konacak zil butonu.
/// - Okunmamış varsa: kırmızı zil + sayaç badge
/// - Hepsi okunmuş: sarı zil (temiz)
///
/// Owner/Assistant: `farms/{activeFarmId}/notifications` içindeki okunmamış
/// kayıtları sayar (vet cevapları, davet cevapları, aktivite log'ları).
///
/// Vet: tüm çiftliklerden gelen okunmamış `vet_requests` sayısını gösterir
/// (collection group query).
class NotificationBellButton extends StatelessWidget {
  /// Vet panel için (FarmPicker AppBar) — `farmId` yerine vet uid'sine göre
  /// tüm çiftliklerdeki okunmamış vet_requests sayılır.
  final bool vetPanel;

  const NotificationBellButton({super.key, this.vetPanel = false});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (vetPanel || user.isVet) {
      return _VetBell(uid: user.uid);
    }

    final farmId = user.activeFarmId;
    if (farmId == null || farmId.isEmpty) return const SizedBox.shrink();
    return _FarmBell(farmId: farmId, uid: user.uid);
  }
}

/// Owner/Assistant zil — farm notifications okunmamış sayısı.
class _FarmBell extends StatelessWidget {
  final String farmId;
  final String uid;
  const _FarmBell({required this.farmId, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: NotificationFeedService.instance
          .streamForUser(farmId: farmId, uid: uid),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        final unreadCount = items.where((n) => !n.isReadBy(uid)).length;
        return _BellIcon(
          unreadCount: unreadCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationsPanelScreen(),
            ),
          ),
        );
      },
    );
  }
}

/// Vet zil — collection group `vet_requests` okunmamış sayısı.
class _VetBell extends StatelessWidget {
  final String uid;
  const _VetBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: VetRequestService.instance.streamAllForVet(uid),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        final unreadCount = items.where((r) => r.readAt == null).length;
        return _BellIcon(
          unreadCount: unreadCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationsPanelScreen(vetMode: true),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable zil ikonu — okunmamış varsa kırmızı + badge, yoksa sarı.
class _BellIcon extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _BellIcon({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Bildirimler',
          icon: Icon(
            hasUnread ? Icons.notifications_active : Icons.notifications_none,
            color: hasUnread ? AppColors.errorRed : AppColors.gold,
          ),
          onPressed: onTap,
        ),
        if (hasUnread)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
