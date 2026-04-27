import 'package:flutter/material.dart';
import '../../../core/design_system/ds.dart';

/// "Bugün X yapılacak, Y uyarı var" — tek satır özet.
class DailyStatusBadge extends StatelessWidget {
  final int todoCount;
  final int warningCount;
  final VoidCallback? onTap;

  const DailyStatusBadge({
    super.key,
    required this.todoCount,
    required this.warningCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final hasActivity = todoCount > 0 || warningCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasActivity
                ? tokens.primary.withValues(alpha: 0.08)
                : tokens.surfaceHighest,
            borderRadius: DsRadius.brMd,
            border: Border.all(
              color: hasActivity
                  ? tokens.primary.withValues(alpha: 0.2)
                  : tokens.border,
              width: 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: hasActivity
                    ? tokens.primary.withValues(alpha: 0.15)
                    : tokens.textTertiary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasActivity ? Icons.today_rounded : Icons.check_circle_outline,
                color: hasActivity ? tokens.primary : tokens.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Bugün',
                      style: DsTypography.caption(color: tokens.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    hasActivity
                        ? '$todoCount yapılacak${warningCount > 0 ? ' · $warningCount uyarı' : ''}'
                        : 'Her şey güncel',
                    style: DsTypography.subtitle(color: tokens.textPrimary),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: tokens.textTertiary, size: 20),
          ]),
        ),
      ),
    );
  }
}
