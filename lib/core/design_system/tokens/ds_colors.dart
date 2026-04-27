import 'package:flutter/material.dart';

/// ÇiftlikPRO Design System — Colors
///
/// Brand kimliği (yeşil) korunur; canlı accent'lar eklenir.
/// Tüm renkler light/dark mode için ayrı tanımlanmıştır.
class DsColors {
  DsColors._();

  // ─── Brand ────────────────────────────────────────────────
  // Marka ana rengi — ÇiftlikPRO yeşili (aynı kalır)
  static const Color brandGreen = Color(0xFF1B5E20);
  static const Color brandGreenDark = Color(0xFF0A2E0F);
  static const Color brandGreenBright = Color(0xFF2E7D32);

  // iOS-like canlı yeşil — CTA/success için
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentGreenDark = Color(0xFF30B34E);

  // ─── Semantic Accents ───────────────────────────────────────
  static const Color gold = Color(0xFFFFD60A);
  static const Color goldDark = Color(0xFFC7A600);

  static const Color errorRed = Color(0xFFFF453A);
  static const Color errorRedDark = Color(0xFFD32F2F);

  static const Color warning = Color(0xFFFF9F0A);
  static const Color warningDark = Color(0xFFE68900);

  static const Color infoBlue = Color(0xFF0A84FF);
  static const Color infoBlueDark = Color(0xFF0066CC);

  static const Color premium = Color(0xFFAF52DE);

  // ─── Neutrals — Light Mode ─────────────────────────────────
  // iOS-inspired neutral scale (0=background, 900=text)
  static const Color neutral0  = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF5F5F7); // iOS light bg
  static const Color neutral100 = Color(0xFFF2F2F7);
  static const Color neutral200 = Color(0xFFE5E5EA);
  static const Color neutral300 = Color(0xFFD1D1D6);
  static const Color neutral400 = Color(0xFFC7C7CC);
  static const Color neutral500 = Color(0xFFAEAEB2);
  static const Color neutral600 = Color(0xFF8E8E93);
  static const Color neutral700 = Color(0xFF636366);
  static const Color neutral800 = Color(0xFF3A3A3C);
  static const Color neutral900 = Color(0xFF1D1D1F); // iOS label color
  static const Color neutral950 = Color(0xFF000000);

  // ─── Neutrals — Dark Mode ──────────────────────────────────
  static const Color darkBg = Color(0xFF000000);       // AMOLED
  static const Color darkSurface = Color(0xFF1C1C1E);  // iOS dark surface
  static const Color darkSurface2 = Color(0xFF2C2C2E); // iOS elevated
  static const Color darkSurface3 = Color(0xFF3A3A3C);
  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkDivider = Color(0xFF2C2C2E);
}

/// Light/Dark'a duyarlı renk tokenları.
/// Hem [BuildContext] ile hem de [Brightness] ile sorgulanabilir.
class DsTokens {
  final Brightness brightness;
  const DsTokens(this.brightness);

  factory DsTokens.of(BuildContext context) =>
      DsTokens(Theme.of(context).brightness);

  bool get isDark => brightness == Brightness.dark;

  // ─── Brand ───────────────────────────────
  Color get primary => isDark ? DsColors.accentGreen : DsColors.brandGreen;
  Color get primaryBright => DsColors.accentGreen;
  Color get onPrimary => Colors.white;

  // ─── Backgrounds ─────────────────────────
  Color get background => isDark ? DsColors.darkBg : DsColors.neutral50;
  Color get surface => isDark ? DsColors.darkSurface : DsColors.neutral0;
  Color get surfaceElevated => isDark ? DsColors.darkSurface2 : DsColors.neutral0;
  Color get surfaceHighest => isDark ? DsColors.darkSurface3 : DsColors.neutral100;

  // ─── Text ────────────────────────────────
  Color get textPrimary => isDark ? Colors.white : DsColors.neutral900;
  Color get textSecondary => isDark ? DsColors.neutral500 : DsColors.neutral600;
  Color get textTertiary => isDark ? DsColors.neutral700 : DsColors.neutral400;
  Color get textOnPrimary => Colors.white;

  // ─── Borders & Dividers ──────────────────
  Color get border => isDark ? DsColors.darkBorder : DsColors.neutral200;
  Color get divider => isDark ? DsColors.darkDivider : DsColors.neutral200;

  // ─── Semantic ─────────────────────────────
  Color get success => DsColors.accentGreen;
  Color get warning => DsColors.warning;
  Color get error => isDark ? DsColors.errorRed : DsColors.errorRedDark;
  Color get info => DsColors.infoBlue;
  Color get gold => DsColors.gold;
  Color get premium => DsColors.premium;

  // ─── Overlays ─────────────────────────────
  /// Kart üstü hafif tint (hover/pressed)
  Color get overlayLight => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.03);
  Color get overlayMedium => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);

  /// Scrim (modal backdrop)
  Color get scrim => Colors.black.withValues(alpha: 0.55);

  // ─── Gradients ───────────────────────────
  LinearGradient get brandGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [DsColors.brandGreen, DsColors.brandGreenBright],
      );

  LinearGradient get vibrantGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [DsColors.accentGreen, DsColors.brandGreenBright],
      );

  LinearGradient get splashGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DsColors.brandGreenDark,
          DsColors.brandGreen,
          DsColors.brandGreenBright,
        ],
      );

  LinearGradient get premiumGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [DsColors.gold, DsColors.premium],
      );
}
