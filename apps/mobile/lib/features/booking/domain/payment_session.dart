import '../../../core/utils/json_utils.dart';

/// Response of the `paytr-create-payment` edge function.
class PaymentSession {
  const PaymentSession({required this.iframeUrl, required this.merchantOid, this.holdExpiresAt});

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      iframeUrl: json['iframe_url'] as String,
      merchantOid: (json['merchant_oid'] as String?) ?? '',
      holdExpiresAt: parseUtcOrNull(json['hold_expires_at']),
    );
  }

  final String iframeUrl;
  final String merchantOid;
  final DateTime? holdExpiresAt;
}

/// Route arguments for the payment WebView screen.
class PaymentArgs {
  const PaymentArgs({required this.bookingId, required this.iframeUrl, required this.holdExpiresAt});

  final String bookingId;
  final String iframeUrl;
  final DateTime holdExpiresAt;
}
