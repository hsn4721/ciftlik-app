import 'package:flutter/animation.dart';

/// ÇiftlikPRO Design System — Motion
///
/// Standart animasyon süreleri ve eğrileri. Amaçsız animasyon yok.
class DsMotion {
  DsMotion._();

  // ─── Durations ────────────────────────────
  /// Hızlı feedback (button press, tap state)
  static const Duration instant = Duration(milliseconds: 100);

  /// Standart transition (hover, expand, fade)
  static const Duration fast = Duration(milliseconds: 200);

  /// Default UI transition
  static const Duration normal = Duration(milliseconds: 300);

  /// Emphasize (page transition, hero)
  static const Duration slow = Duration(milliseconds: 400);

  /// Extra emphasize (splash, onboarding)
  static const Duration extraSlow = Duration(milliseconds: 600);

  // ─── Curves ───────────────────────────────
  /// Default UI curve — iOS-like spring
  static const Curve standard = Curves.easeInOutCubic;

  /// Enter (öğe ekrana girerken)
  static const Curve enter = Curves.easeOutCubic;

  /// Exit (öğe ekrandan çıkarken)
  static const Curve exit = Curves.easeInCubic;

  /// Emphasize — kritik vurgu
  static const Curve emphasize = Curves.easeOutQuart;

  /// Spring — elastic feel
  static const Curve spring = Curves.easeOutBack;

  /// Decelerate — scroll benzeri
  static const Curve decelerate = Curves.decelerate;
}
