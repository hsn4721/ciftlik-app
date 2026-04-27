import 'package:flutter/material.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_radius.dart';
import '../tokens/ds_spacing.dart';

/// Premium bottom sheet — başlık + content + opsiyonel action bar.
/// showModalBottomSheet yerine kullanılır.
class DsBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsets contentPadding;

  const DsBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });

  /// Helper — showModalBottomSheet ile kullanım.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: DsRadius.sheetTop,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: tokens.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title!, style: DsTypography.title(color: tokens.textPrimary)),
                          if (subtitle != null) ...[
                            DsSpacing.vXxs,
                            Text(subtitle!, style: DsTypography.body(color: tokens.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: tokens.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.divider),
            ],
            Flexible(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              Divider(height: 1, color: tokens.divider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) DsSpacing.hXs,
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
