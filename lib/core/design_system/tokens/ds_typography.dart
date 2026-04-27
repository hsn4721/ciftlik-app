import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ÇiftlikPRO Design System — Typography
///
/// Inter font ailesi — premium okunabilirlik, hem iOS hem Android'de native hisli.
/// Scale: Display / Title / Headline / Body / Label / Caption
class DsTypography {
  DsTypography._();

  /// Font family — Inter (Google Fonts)
  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Roboto';

  /// Display — büyük başlıklar (splash, onboarding)
  static TextStyle display({Color? color}) => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.1,
        color: color,
      );

  /// Title Large — ekran başlıkları
  static TextStyle titleLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.2,
        color: color,
      );

  /// Title — bölüm başlıkları
  static TextStyle title({Color? color}) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        color: color,
      );

  /// Headline — kart başlıkları
  static TextStyle headline({Color? color}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// Subtitle — alt başlık
  static TextStyle subtitle({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: color,
      );

  /// Body — standart metin
  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        height: 1.45,
        color: color,
      );

  /// Body Small — ikincil metin
  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// Label — chip, button, badge
  static TextStyle label({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.3,
        color: color,
      );

  /// Label Small — küçük rozet
  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
        color: color,
      );

  /// Caption — küçük açıklama, tarih
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.3,
        color: color,
      );

  /// Mono — sayı/tutar (tabular figures)
  static TextStyle mono({Color? color, double size = 15, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.3,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Number display — büyük rakamlar (KPI, hero stats)
  static TextStyle numberDisplay({Color? color}) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.0,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Material 3 TextTheme — eski API uyumluluğu
  static TextTheme buildTextTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: display(color: primary),
        displayMedium: titleLarge(color: primary),
        displaySmall: title(color: primary),
        headlineLarge: title(color: primary),
        headlineMedium: headline(color: primary),
        headlineSmall: subtitle(color: primary),
        titleLarge: headline(color: primary),
        titleMedium: subtitle(color: primary),
        titleSmall: label(color: primary),
        bodyLarge: body(color: primary),
        bodyMedium: bodySmall(color: secondary),
        bodySmall: caption(color: secondary),
        labelLarge: label(color: primary),
        labelMedium: labelSmall(color: primary),
        labelSmall: caption(color: secondary),
      );
}
