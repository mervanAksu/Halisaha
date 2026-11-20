/// Build-time configuration. Values come from `--dart-define-from-file=env/local.json`.
/// No secrets live here: the Supabase anon key is a public client key protected by RLS.
abstract final class AppConfig {
  static const String appName = 'Halısaha';
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const String supportPhone = String.fromEnvironment('SUPPORT_PHONE');
  static const String supportWhatsapp = String.fromEnvironment('SUPPORT_WHATSAPP');
  static const String websiteUrl = String.fromEnvironment('WEBSITE_URL');
  static const String legalBaseUrl = String.fromEnvironment('LEGAL_BASE_URL');

  /// Public Supabase Storage bucket holding venue photos.
  static const String venuePhotosBucket = 'venue-photos';

  /// Legal page slugs, appended to [legalBaseUrl].
  static const String legalAbout = 'about';
  static const String legalPrivacy = 'privacy';
  static const String legalTerms = 'terms';
  static const String legalKvkk = 'kvkk';
  static const String legalDistanceSales = 'distance-sales';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// `<LEGAL_BASE_URL>/<slug>`; trailing slashes on the base are tolerated.
  static String legalUrl(String slug) {
    final base = legalBaseUrl.endsWith('/') ? legalBaseUrl.substring(0, legalBaseUrl.length - 1) : legalBaseUrl;
    return '$base/$slug';
  }
}
