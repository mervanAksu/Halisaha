/// Route paths in one place.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String onboarding = '/onboarding';

  // Shell branches (bottom navigation).
  static const String favorites = '/favorites';
  static const String matches = '/matches';
  static const String home = '/';
  static const String support = '/support';
  static const String profile = '/profile';
  static const String notificationSettings = '/profile/notifications';

  // Full-screen routes above the shell.
  static const String venueDetail = '/venue/:id';
  static const String bookingSummary = '/booking/summary';
  static const String payment = '/payment';
  static const String bookingResult = '/booking-result/:id';

  /// In-app owner panel (role owner/admin only; the router redirects everyone else).
  static const String owner = '/owner';
  static const String ownerLogin = '/owner/login';
  static const String ownerNotOwner = '/owner/not-owner';

  static String venue(String id) => '/venue/$id';
  static String result(String bookingId) => '/booking-result/$bookingId';
  static String otpFor(String e164Phone) => '$otp?phone=${Uri.encodeQueryComponent(e164Phone)}';
}
