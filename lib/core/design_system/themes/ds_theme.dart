import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import '../tokens/ds_radius.dart';

/// ÇiftlikPRO Design System — ThemeData builder.
///
/// Sadece light tema — dark mode kullanılmıyor. Yeni DS tokenlarına göre
/// tüm Material bileşenleri stillendirilir.
class DsTheme {
  DsTheme._();

  static ThemeData light() => _build();

  static ThemeData _build() {
    const brightness = Brightness.light;
    final tokens = DsTokens(brightness);

    const colorScheme = ColorScheme.light(
      primary: DsColors.brandGreen,
      onPrimary: Colors.white,
      secondary: DsColors.gold,
      onSecondary: Colors.black,
      error: DsColors.errorRedDark,
      surface: DsColors.neutral0,
      onSurface: DsColors.neutral900,
    );

    final textTheme = DsTypography.buildTextTheme(
      tokens.textPrimary,
      tokens.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      fontFamily: DsTypography.fontFamily,
      textTheme: textTheme,

      // ─── AppBar — Marka Yeşili ────────────
      appBarTheme: AppBarTheme(
        backgroundColor: DsColors.brandGreen,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: DsTypography.title(color: Colors.white).copyWith(
          fontSize: 18, fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: DsColors.neutral0,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // ─── Card ─────────────────────────────
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.brLg,
          side: BorderSide(color: tokens.border, width: 0.5),
        ),
      ),

      // ─── Elevated Button ──────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: tokens.surfaceHighest,
          disabledForegroundColor: tokens.textTertiary,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: DsRadius.brMd),
          textStyle: DsTypography.subtitle(color: Colors.white),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ─── Text Button ──────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          shape: const RoundedRectangleBorder(borderRadius: DsRadius.brSm),
          textStyle: DsTypography.subtitle(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // ─── Outlined Button ──────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.border, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: DsRadius.brMd),
          textStyle: DsTypography.subtitle(),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // ─── Input ────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceHighest,
        hintStyle: DsTypography.body(color: tokens.textTertiary),
        labelStyle: DsTypography.body(color: tokens.textSecondary),
        floatingLabelStyle: DsTypography.label(color: tokens.primary),
        prefixIconColor: tokens.textSecondary,
        suffixIconColor: tokens.textSecondary,
        border: OutlineInputBorder(
          borderRadius: DsRadius.brMd,
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DsRadius.brMd,
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DsRadius.brMd,
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DsRadius.brMd,
          borderSide: BorderSide(color: tokens.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DsRadius.brMd,
          borderSide: BorderSide(color: tokens.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ─── TabBar (AppBar altında - yeşil üstünde beyaz) ────
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: DsTypography.label(color: Colors.white),
        unselectedLabelStyle: DsTypography.label(color: Colors.white70),
        indicatorColor: DsColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.white10),
      ),

      // ─── Bottom Navigation ────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: tokens.primary,
        unselectedItemColor: tokens.textSecondary,
        selectedLabelStyle: DsTypography.labelSmall(),
        unselectedLabelStyle: DsTypography.labelSmall(),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      // ─── Divider ──────────────────────────
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 0.5,
        space: 0,
      ),

      // ─── Chip ─────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceHighest,
        selectedColor: tokens.primary.withValues(alpha: 0.15),
        labelStyle: DsTypography.label(color: tokens.textPrimary),
        secondaryLabelStyle: DsTypography.label(color: tokens.primary),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.brSm),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: true,
        checkmarkColor: tokens.primary,
      ),

      // ─── Switch ───────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : tokens.surfaceHighest),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? tokens.primary : tokens.border),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // ─── Dialog ───────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.brXl),
        titleTextStyle: DsTypography.headline(color: tokens.textPrimary),
        contentTextStyle: DsTypography.body(color: tokens.textPrimary),
      ),

      // ─── Bottom Sheet ─────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: tokens.textTertiary,
      ),

      // ─── Snackbar ─────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DsColors.neutral900,
        contentTextStyle: DsTypography.body(color: Colors.white),
        actionTextColor: DsColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.brMd),
      ),

      // ─── ListTile ─────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: tokens.textSecondary,
        titleTextStyle: DsTypography.subtitle(color: tokens.textPrimary),
        subtitleTextStyle: DsTypography.bodySmall(color: tokens.textSecondary),
      ),

      // ─── Progress ─────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.primary,
        linearTrackColor: tokens.surfaceHighest,
        circularTrackColor: tokens.surfaceHighest,
      ),

      // ─── Splash & Highlight ───────────────
      splashFactory: InkSparkle.splashFactory,
      splashColor: tokens.primary.withValues(alpha: 0.08),
      highlightColor: tokens.primary.withValues(alpha: 0.04),
    );
  }
}
