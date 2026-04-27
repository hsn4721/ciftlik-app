import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_radius.dart';
import '../tokens/ds_motion.dart';

/// Button variantları — tasarım sistemi hiyerarşisi.
enum DsButtonVariant {
  /// Dolu yeşil — ana CTA
  primary,
  /// Outline — ikincil eylem
  secondary,
  /// Sadece metin — üçüncül eylem
  ghost,
  /// Kırmızı — silme/tehlikeli eylem
  destructive,
}

enum DsButtonSize { sm, md, lg }

/// Premium primary button — scale animation + haptic feedback.
class DsButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expanded;
  final bool haptic;

  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = true,
    this.haptic = true,
  });

  const DsButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = DsButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = true,
    this.haptic = true,
  }) : variant = DsButtonVariant.secondary;

  const DsButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = DsButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = false,
    this.haptic = true,
  }) : variant = DsButtonVariant.ghost;

  const DsButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.size = DsButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = true,
    this.haptic = true,
  }) : variant = DsButtonVariant.destructive;

  @override
  State<DsButton> createState() => _DsButtonState();
}

class _DsButtonState extends State<DsButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: DsMotion.instant,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case DsButtonSize.sm: return 40;
      case DsButtonSize.md: return 52;
      case DsButtonSize.lg: return 58;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case DsButtonSize.sm: return 13;
      case DsButtonSize.md: return 15;
      case DsButtonSize.lg: return 16;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case DsButtonSize.sm: return const EdgeInsets.symmetric(horizontal: 14);
      case DsButtonSize.md: return const EdgeInsets.symmetric(horizontal: 20);
      case DsButtonSize.lg: return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final enabled = widget.onPressed != null && !widget.loading;

    Color bg;
    Color fg;
    BoxBorder? border;
    switch (widget.variant) {
      case DsButtonVariant.primary:
        bg = enabled ? tokens.primary : tokens.surfaceHighest;
        fg = enabled ? Colors.white : tokens.textTertiary;
        break;
      case DsButtonVariant.secondary:
        bg = Colors.transparent;
        fg = enabled ? tokens.textPrimary : tokens.textTertiary;
        border = Border.all(color: tokens.border, width: 1);
        break;
      case DsButtonVariant.ghost:
        bg = Colors.transparent;
        fg = enabled ? tokens.primary : tokens.textTertiary;
        break;
      case DsButtonVariant.destructive:
        bg = enabled ? DsColors.errorRed : tokens.surfaceHighest;
        fg = enabled ? Colors.white : tokens.textTertiary;
        break;
    }

    Widget child;
    if (widget.loading) {
      child = SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
      );
    } else {
      child = Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.leadingIcon != null) ...[
            Icon(widget.leadingIcon, size: _fontSize + 3, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: DsTypography.subtitle(color: fg).copyWith(fontSize: _fontSize),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(widget.trailingIcon, size: _fontSize + 3, color: fg),
          ],
        ],
      );
    }

    final inner = Container(
      height: _height,
      width: widget.expanded ? double.infinity : null,
      padding: _padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DsRadius.brMd,
        border: border,
        boxShadow: enabled && widget.variant == DsButtonVariant.primary
            ? [
                BoxShadow(
                  color: tokens.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : enabled && widget.variant == DsButtonVariant.destructive
                ? [
                    BoxShadow(
                      color: DsColors.errorRed.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
      ),
      child: child,
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => _scale.reverse() : null,
      onTapUp: enabled ? (_) => _scale.forward() : null,
      onTapCancel: enabled ? () => _scale.forward() : null,
      onTap: enabled
          ? () {
              if (widget.haptic) {
                HapticFeedback.lightImpact();
              }
              widget.onPressed?.call();
            }
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: inner,
      ),
    );
  }
}

/// Icon-only button — 44x44 tap area (Apple HIG).
class DsIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  final bool filled;

  const DsIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 22,
    this.tooltip,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final c = color ?? tokens.textPrimary;
    final btn = InkWell(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      borderRadius: DsRadius.brPill,
      child: Container(
        width: 44, height: 44,
        alignment: Alignment.center,
        decoration: filled
            ? BoxDecoration(
                color: tokens.surfaceHighest,
                borderRadius: DsRadius.brPill,
              )
            : null,
        child: Icon(icon, size: size, color: c),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
