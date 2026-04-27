import 'package:flutter/material.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';

/// Large title scroll-collapse scaffold — iOS-inspired.
/// AppBar ilk başta büyük, scroll edilince küçülür.
class DsScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool centerTitle;
  final List<Widget>? slivers;
  final Color? backgroundColor;

  const DsScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.centerTitle = false,
    this.slivers,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = DsTokens.of(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? tokens.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: child,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: DsTypography.title(color: tokens.textPrimary),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: DsTypography.caption(color: tokens.textSecondary),
              ),
          ],
        ),
        leading: leading,
        actions: actions,
        centerTitle: centerTitle,
      ),
    );
  }
}
