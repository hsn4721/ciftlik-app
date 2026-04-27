import 'package:flutter/material.dart';

/// ÇiftlikPRO Design System — Elevation & Shadows
///
/// 5-katmanlı gölge sistemi. Dark mode'da gölgeler sakin,
/// light mode'da daha belirgin.
class DsElevation {
  DsElevation._();

  /// Level 0 — gölge yok (düz surface)
  static const List<BoxShadow> none = [];

  /// Level 1 — ince fark (kart)
  static List<BoxShadow> sm({bool dark = false}) => dark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0F000000), // 6% opacity
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ];

  /// Level 2 — elevated card
  static List<BoxShadow> md({bool dark = false}) => dark
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14000000), // 8% opacity
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ];

  /// Level 3 — modal, FAB
  static List<BoxShadow> lg({bool dark = false}) => dark
      ? const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F000000), // 12% opacity
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  /// Level 4 — hero card, bottom sheet üstü
  static List<BoxShadow> xl({bool dark = false}) => dark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x29000000), // 16% opacity
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ];

  /// Renkli parlama — primary button, hero accent
  static List<BoxShadow> colored(Color color, {double opacity = 0.3, double blur = 20, double dy = 8}) =>
      [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, dy),
        ),
      ];
}
