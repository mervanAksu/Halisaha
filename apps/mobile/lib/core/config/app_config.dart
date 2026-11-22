/// Build-time configuration. Values come from `--dart-define-from-file=env/local.json`.
/// No secrets live here: the Supabase anon key is a public client key protected by RLS.
abstract final class AppConfig {
  static const String appName = 'Rövanş';
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const String supportPhone = String.fromEnvironment('SUPPORT_PHONE');
  static const String supportWhatsapp = String.fromEnvironment('SUPPORT_WHATSAPP');
  /// Web panel (apps/owner_panel) address shown in the owner account sheet; the row is hidden when empty.
  static const String ownerPanelUrl = String.fromEnvironment('OWNER_PANEL_URL');
  static const String websiteUrl = String.fromEnvironment('WEBSITE_URL');
  static const String legalBaseUrl = String.fromEnvironment('LEGAL_BASE_URL');

  /// Base URL PayTR redirects to after a payment attempt (same value as the edge function secret
  /// `PAYMENT_RESULT_BASE_URL`). Its host is the only non-PayTR host the payment WebView may open.
  static const String paymentResultBaseUrl = String.fromEnvironment('PAYMENT_RESULT_BASE_URL');

  /// Public Supabase Storage bucket holding venue photos.
  static const String venuePhotosBucket = 'venue-photos';

  /// Legal page slugs, appended to [legalBaseUrl].
  static const String legalAbout = 'about';
  static const String legalPrivacy = 'privacy';
  static const String legalTerms = 'terms';
  static const String legalKvkk = 'kvkk';
  static const String legalDistanceSales = 'distance-sales';

  /// Backend-free preview build (`--dart-define=DEMO_MODE=true`): in-memory repositories,
  /// no Supabase, no PayTR. Used for the GitHub Pages web preview.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// `<LEGAL_BASE_URL>/<slug>`; trailing slashes on the base are tolerated.
  static String legalUrl(String slug) {
    final base = legalBaseUrl.endsWith('/') ? legalBaseUrl.substring(0, legalBaseUrl.length - 1) : legalBaseUrl;
    return '$base/$slug';
  }
}
