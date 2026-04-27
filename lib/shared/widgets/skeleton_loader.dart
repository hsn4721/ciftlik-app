import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// CircularProgressIndicator yerine daha profesyonel görünüm sağlayan
/// shimmer efektli placeholder.
///
/// Kullanım:
/// ```dart
/// loading ? const SkeletonList(itemCount: 6) : ListView(...)
/// ```
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => SkeletonCard(height: itemHeight),
    );
  }
}

class SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 72,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final shift = _ctrl.value;
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (shift * 2), 0),
              end: Alignment(1.0 + (shift * 2), 0),
              colors: [
                AppColors.divider.withValues(alpha: 0.3),
                AppColors.divider.withValues(alpha: 0.6),
                AppColors.divider.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Daha kompakt shimmer bar (örn. istatistik rakamı için).
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const SkeletonLine({super.key, required this.width, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
