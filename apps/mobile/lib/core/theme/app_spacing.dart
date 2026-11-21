/// Spacing and radius tokens (multiples of 4, docs/DESIGN.md).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

abstract final class AppRadius {
  static const double button = 14;
  static const double card = 16;
  static const double slot = 12;
}

abstract final class AppSizes {
  /// Minimum touch target (docs/DESIGN.md "Dokunma hedefi").
  static const double minTarget = 48;
}
