import 'package:flutter/material.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';

/// iOS-style list tile — settings/menu için.
class DsListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final Widget? leading;
  final Color? leadingColor;
  final Color? leadingIconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;

  const DsListTile({
    super.key,
    this.leadingIcon,
    this.leading,
    this.leadingColor,
    this.leadingIconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    final titleColor = destructive ? tokens.error : tokens.textPrimary;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      final bg = leadingColor ?? tokens.primary;
      final iconColor = leadingIconColor ?? Colors.white;
      leadingWidget = Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: destructive ? tokens.error : bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          leadingIcon,
          color: iconColor,
          size: 18,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DsTypography.subtitle(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: DsTypography.caption(color: tokens.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText!,
                  style: DsTypography.body(color: tokens.textSecondary),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: tokens.textTertiary, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
