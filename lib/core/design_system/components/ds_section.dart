import 'package:flutter/material.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_colors.dart';

/// Başlıklı bölüm sarmalayıcısı — tutarlı dikey hiyerarşi.
class DsSection extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final EdgeInsets padding;
  final double gap;

  const DsSection({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: DsTypography.headline(color: tokens.textPrimary),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: DsTypography.label(color: tokens.primary),
                        ),
                        Icon(Icons.chevron_right, color: tokens.primary, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: gap),
          ],
          child,
        ],
      ),
    );
  }
}

/// iOS-style gruplu settings section.
class DsGroupedSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  const DsGroupedSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              title!.toUpperCase(),
              style: DsTypography.labelSmall(color: tokens.textSecondary),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 0.5, thickness: 0.5, color: tokens.divider, indent: 52),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              footer!,
              style: DsTypography.caption(color: tokens.textSecondary),
            ),
          ),
      ],
    );
  }
}
