import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Silme sonrası "Geri Al" imkanı sağlayan SnackBar yardımcısı.
///
/// Kullanım:
/// ```dart
/// UndoSnackbar.show(
///   context,
///   message: 'Hayvan silindi',
///   onUndo: () async => await repo.insertAnimal(deletedCopy),
/// );
/// ```
///
/// SnackBar 4 saniye gösterilir. Kullanıcı "Geri Al"'a basınca [onUndo]
/// callback çalışır; basmazsa hiçbir şey olmaz (silme kalıcıdır).
class UndoSnackbar {
  UndoSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    required Future<void> Function() onUndo,
    Duration duration = const Duration(seconds: 4),
    String actionLabel = 'Geri Al',
    String? restoredMessage,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: actionLabel,
          textColor: AppColors.gold,
          onPressed: () async {
            try {
              await onUndo();
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(restoredMessage ?? 'Geri alındı'),
                  backgroundColor: AppColors.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Geri alınamadı: $e'),
                  backgroundColor: AppColors.errorRed,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
