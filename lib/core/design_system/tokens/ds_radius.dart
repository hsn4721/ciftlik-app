import 'package:flutter/widgets.dart';

/// ÇiftlikPRO Design System — Border Radius
class DsRadius {
  DsRadius._();

  static const double xs = 4;   // chip, küçük rozet
  static const double sm = 8;   // button, küçük kart
  static const double md = 12;  // card, input
  static const double lg = 16;  // elevated card, sheet içi
  static const double xl = 20;  // bottom sheet
  static const double xxl = 24; // hero card
  static const double pill = 999; // pill-shaped button

  // ─── Hazır BorderRadius ──────────────────────
  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Bottom sheet için (sadece üst köşeler)
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );

  /// Sol kenar vurgulu kart için
  static const BorderRadius leadingIndicator = BorderRadius.only(
    topLeft: Radius.circular(md),
    bottomLeft: Radius.circular(md),
  );
}
