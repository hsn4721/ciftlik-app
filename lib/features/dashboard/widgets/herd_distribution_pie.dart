import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/design_system/ds.dart';

class HerdDistributionSlice {
  final String label;
  final int count;
  final Color color;
  const HerdDistributionSlice({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Sürü Dağılım Pie — donut chart + legend.
class HerdDistributionPie extends StatelessWidget {
  final List<HerdDistributionSlice> slices;
  final VoidCallback? onTap;

  const HerdDistributionPie({
    super.key,
    required this.slices,
    this.onTap,
  });

  int get _total => slices.fold<int>(0, (sum, s) => sum + s.count);

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final total = _total;

    return DsCard(
      variant: DsCardVariant.elevated,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Sürü Dağılımı',
                style: DsTypography.headline(color: tokens.textPrimary)),
            const Spacer(),
            Text('$total hayvan',
                style: DsTypography.label(color: tokens.textSecondary)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              // Donut
              SizedBox(
                width: 110, height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(
                    slices: slices,
                    trackColor: tokens.surfaceHighest,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$total',
                            style: DsTypography.title(color: tokens.textPrimary)
                                .copyWith(fontSize: 22)),
                        Text('toplam',
                            style: DsTypography.caption(color: tokens.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: slices.map((s) {
                    final pct = total == 0 ? 0.0 : (s.count / total * 100);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.label,
                              style: DsTypography.bodySmall(color: tokens.textPrimary)),
                        ),
                        Text('${s.count}',
                            style: DsTypography.label(color: tokens.textPrimary)),
                        const SizedBox(width: 6),
                        Text('%${pct.toStringAsFixed(0)}',
                            style: DsTypography.caption(color: tokens.textSecondary)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<HerdDistributionSlice> slices;
  final Color trackColor;
  _DonutPainter({required this.slices, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 16) / 2;

    // Track
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);

    final total = slices.fold<int>(0, (a, s) => a + s.count);
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep - 0.02, false, paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
