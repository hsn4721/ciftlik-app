import 'package:flutter/material.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';

/// Premium avatar — inisyaller veya foto, renkli ring opsiyonlu.
class DsAvatar extends StatelessWidget {
  final String? initials;
  final String? imageUrl;
  final ImageProvider? imageProvider;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? ringColor;
  final double ringWidth;

  const DsAvatar({
    super.key,
    this.initials,
    this.imageUrl,
    this.imageProvider,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.ringColor,
    this.ringWidth = 2,
  });

  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final bg = backgroundColor ?? tokens.primary.withValues(alpha: 0.12);
    final fg = foregroundColor ?? tokens.primary;

    Widget circle = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        image: imageProvider != null
            ? DecorationImage(image: imageProvider!, fit: BoxFit.cover)
            : null,
      ),
      child: (imageProvider == null && imageUrl == null && initials != null)
          ? Center(
              child: Text(
                initials!,
                style: DsTypography.subtitle(color: fg).copyWith(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );

    if (ringColor != null) {
      circle = Container(
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          color: ringColor,
          shape: BoxShape.circle,
        ),
        child: circle,
      );
    }

    return circle;
  }
}
