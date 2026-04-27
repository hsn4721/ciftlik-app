import 'package:flutter/material.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_radius.dart';
import '../tokens/ds_elevation.dart';

enum DsCardVariant {
  /// Surface + gölge (default)
  elevated,
  /// Sadece kenar, gölge yok
  outlined,
  /// Dolgu rengi (subtle highlight)
  filled,
  /// Transparent arka plan + border
  ghost,
}

/// Premium card — hiyerarşik varyantlar + opsiyonel leading color bar.
class DsCard extends StatelessWidget {
  final Widget child;
  final DsCardVariant variant;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? leadingBarColor;
  final double leadingBarWidth;
  final bool selected;
  final BorderRadius? borderRadius;

  const DsCard({
    super.key,
    required this.child,
    this.variant = DsCardVariant.elevated,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.leadingBarColor,
    this.leadingBarWidth = 4,
    this.selected = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final radius = borderRadius ?? DsRadius.brLg;

    Color bg;
    Border? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case DsCardVariant.elevated:
        bg = tokens.surface;
        shadow = DsElevation.sm(dark: tokens.isDark);
        break;
      case DsCardVariant.outlined:
        bg = tokens.surface;
        border = Border.all(color: tokens.border, width: 0.5);
        break;
      case DsCardVariant.filled:
        bg = tokens.surfaceHighest;
        break;
      case DsCardVariant.ghost:
        bg = Colors.transparent;
        border = Border.all(color: tokens.border, width: 0.5);
        break;
    }

    if (selected) {
      bg = tokens.primary.withValues(alpha: 0.08);
      border = Border.all(color: tokens.primary, width: 1.5);
      shadow = null;
    }

    Widget inner = Container(
      padding: padding,
      child: child,
    );

    if (leadingBarColor != null) {
      inner = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: leadingBarWidth, color: leadingBarColor),
          Expanded(child: inner),
        ],
      );
    }

    final container = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
        boxShadow: shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );

    if (onTap == null && onLongPress == null) return container;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        splashColor: tokens.primary.withValues(alpha: 0.08),
        highlightColor: tokens.primary.withValues(alpha: 0.04),
        child: container,
      ),
    );
  }
}

/// Üst kısmı büyük ve renkli "hero" card — dashboard vb. ana vurgu için.
class DsHeroCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const DsHeroCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final g = gradient ?? tokens.brandGradient;

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: DsRadius.brXxl,
        boxShadow: DsElevation.colored(DsColors.brandGreen, blur: 24, dy: 10, opacity: 0.3),
      ),
      child: child,
    );

    if (onTap == null) return inner;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brXxl,
        child: inner,
      ),
    );
  }
}
