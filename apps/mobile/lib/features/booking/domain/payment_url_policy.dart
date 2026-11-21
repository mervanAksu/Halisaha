/// What the payment WebView does with a navigation request.
enum PaymentNavigation {
  /// Let the page load.
  allow,

  /// The merchant result URL was reached: the attempt is over, go read the booking status.
  finish,

  /// Refuse the navigation.
  block,
}

/// Path fragment of the merchant result page (`PAYMENT_RESULT_BASE_URL` contains it).
const String paymentResultPathMarker = '/payment/result';

/// `*.paytr.com` (or `paytr.com` itself). `evilpaytr.com` and `paytr.com.evil.net` do not match.
bool isPaytrHost(String host) {
  final h = host.toLowerCase();
  return h == 'paytr.com' || h.endsWith('.paytr.com');
}

/// Host of the configured `PAYMENT_RESULT_BASE_URL`, or null when unset/invalid/not https.
String? resultHostOf(String resultBaseUrl) {
  if (resultBaseUrl.trim().isEmpty) return null;
  final uri = Uri.tryParse(resultBaseUrl.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri.host.toLowerCase();
}

/// Pure allow-list for the payment WebView.
///
///  * Main-frame navigations: only `https` to `*.paytr.com` or the [resultBaseUrl] host (port 443).
///    A URL containing [paymentResultPathMarker] on such a host means "attempt finished".
///  * Sub-frame requests ([isMainFrame] false): `https` only. The issuing bank's 3-D Secure page is
///    embedded by the PayTR page as a frame on a bank-owned domain, so frames cannot be limited to
///    PayTR hosts without breaking card payments. Frames can never navigate the top-level page.
///  * Everything else (http, file, intent, javascript, data, about, custom schemes, userinfo hosts
///    that resolve elsewhere, unparsable text) is blocked.
PaymentNavigation decidePaymentNavigation(
  String url, {
  required bool isMainFrame,
  required String resultBaseUrl,
}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return PaymentNavigation.block;
  if (uri.hasPort && uri.port != 443) return PaymentNavigation.block;
  if (!isMainFrame) return PaymentNavigation.allow;

  final host = uri.host.toLowerCase();
  final resultHost = resultHostOf(resultBaseUrl);
  final hostAllowed = isPaytrHost(host) || (resultHost != null && host == resultHost);
  if (!hostAllowed) return PaymentNavigation.block;
  if (uri.path.contains(paymentResultPathMarker)) return PaymentNavigation.finish;
  return PaymentNavigation.allow;
}

/// Whether the iframe URL handed out by the server may be loaded at all: https and a PayTR host.
bool isTrustedPaymentStartUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  if (uri.hasPort && uri.port != 443) return false;
  return isPaytrHost(uri.host);
}
