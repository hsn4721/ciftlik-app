import 'package:flutter/material.dart';
import '../../../core/design_system/ds.dart';

class WeeklyStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const WeeklyStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Haftalık özet — "Bu hafta X süt, Y aşı, Z doğum" 4-metrik grid.
class WeeklySummaryCard extends StatelessWidget {
  final List<WeeklyStat> stats;
  final String title;
  final VoidCallback? onTap;

  const WeeklySummaryCard({
    super.key,
    required this.stats,
    this.title = 'Bu Hafta',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return DsCard(
      variant: DsCardVariant.elevated,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_view_week_rounded, size: 16, color: tokens.textSecondary),
            const SizedBox(width: 6),
            Text(title,
                style: DsTypography.headline(color: tokens.textPrimary)),
          ]),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: stats.map((s) => _MiniStat(stat: s)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final WeeklyStat stat;
  const _MiniStat({required this.stat});

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.06),
        borderRadius: DsRadius.brSm,
        border: Border.all(color: stat.color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.15),
            borderRadius: DsRadius.brSm,
          ),
          child: Icon(stat.icon, size: 16, color: stat.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stat.value,
                  style: DsTypography.title(color: tokens.textPrimary)
                      .copyWith(fontSize: 16, height: 1.1),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(stat.label,
                  style: DsTypography.caption(color: tokens.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}
