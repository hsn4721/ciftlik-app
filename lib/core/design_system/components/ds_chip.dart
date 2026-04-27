import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_radius.dart';

/// Selectable filter chip — modern pill style.
class DsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const DsFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: DsRadius.brPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.primary : tokens.surfaceHighest,
          borderRadius: DsRadius.brPill,
          border: Border.all(
            color: selected ? tokens.primary : tokens.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: DsTypography.label(
                color: selected ? Colors.white : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge — durum göstergesi (dot + label).
class DsBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool showDot;
  final double fontSize;

  const DsBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.showDot = false,
    this.fontSize = 11,
  });

  const DsBadge.success({super.key, required this.label, this.icon, this.showDot = false, this.fontSize = 11})
      : color = DsColors.accentGreen;
  const DsBadge.warning({super.key, required this.label, this.icon, this.showDot = false, this.fontSize = 11})
      : color = DsColors.warning;
  const DsBadge.error({super.key, required this.label, this.icon, this.showDot = false, this.fontSize = 11})
      : color = DsColors.errorRed;
  const DsBadge.info({super.key, required this.label, this.icon, this.showDot = false, this.fontSize = 11})
      : color = DsColors.infoBlue;

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final c = color ?? tokens.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showDot ? 8 : 10,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: DsRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: DsTypography.labelSmall(color: c).copyWith(fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}

/// Count badge (notification dot) — overlay style.
class DsCountBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final int maxCount;

  const DsCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.maxCount = 99,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final display = count > maxCount ? '$maxCount+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4, right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: DsColors.errorRed,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: DsTokens.of(context).surface, width: 1.5),
            ),
            child: Text(
              display,
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
