import 'package:flutter/material.dart';
import '../tokens/ds_motion.dart';

/// Premium sayfa geçişleri — iOS-style slide + fade.
class DsPageRoute<T> extends PageRouteBuilder<T> {
  DsPageRoute({
    required WidgetBuilder builder,
    Duration duration = DsMotion.slow,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, anim, secAnim) => builder(context),
          transitionsBuilder: (context, anim, secAnim, child) {
            if (fullscreenDialog) {
              // Aşağıdan yukarı slide (iOS modal)
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: DsMotion.emphasize)),
                child: child,
              );
            }
            // Sağdan sola slide + fade (iOS push)
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.25, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: DsMotion.emphasize)),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
        );
}

/// Fade-only route — daha sade geçişler için.
class DsFadeRoute<T> extends PageRouteBuilder<T> {
  DsFadeRoute({
    required WidgetBuilder builder,
    Duration duration = DsMotion.normal,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, anim, secAnim) => builder(context),
          transitionsBuilder: (context, anim, secAnim, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        );
}
