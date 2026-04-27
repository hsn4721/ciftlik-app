import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/design_system/ds.dart';

/// Çiftlik Sağlık Skoru — tek rozet (0-100).
/// - Hasta hayvan sayısı
/// - Eksik aşı sayısı (approx)
/// - Geciken ödemeler
/// - Düşük stoklar
/// gibi metriklerden hesaplanır; şimdilik dışarıdan score alır.
class FarmHealthScore extends StatelessWidget {
  final int score; // 0-100
  final int issueCount;
  final String? subtitle;
  final VoidCallback? onTap;

  const FarmHealthScore({
    super.key,
    required this.score,
    this.issueCount = 0,
    this.subtitle,
    this.onTap,
  });

  Color _colorFor(int s) {
    if (s >= 85) return DsColors.accentGreen;
    if (s >= 65) return DsColors.gold;
    return DsColors.errorRed;
  }

  String _labelFor(int s) {
    if (s >= 85) return 'Mükemmel';
    if (s >= 65) return 'İyi';
    if (s >= 40) return 'Dikkat';
    return 'Acil';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final color = _colorFor(score);
    final label = _labelFor(score);

    return DsCard(
      variant: DsCardVariant.elevated,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        // Büyük dairesel gösterge
        SizedBox(
          width: 68, height: 68,
          child: CustomPaint(
            painter: _ScoreRing(progress: score / 100, color: color, trackColor: tokens.surfaceHighest),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$score',
                      style: DsTypography.title(color: tokens.textPrimary).copyWith(
                          fontSize: 20, height: 1.0)),
                  Text('/100',
                      style: DsTypography.caption(color: tokens.textSecondary).copyWith(fontSize: 8)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('Çiftlik Sağlık Skoru',
                    style: DsTypography.caption(color: tokens.textSecondary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: DsRadius.brSm,
                  ),
                  child: Text(label,
                      style: DsTypography.labelSmall(color: color)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                subtitle ?? (issueCount == 0
                    ? 'Tüm metrikler güncel'
                    : '$issueCount konu dikkat gerektiriyor'),
                style: DsTypography.bodySmall(color: tokens.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: tokens.textTertiary, size: 22),
      ]),
    );
  }
}

class _ScoreRing extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  _ScoreRing({required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 8) / 2;

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.7), color],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRing old) =>
      old.progress != progress || old.color != color;
}
