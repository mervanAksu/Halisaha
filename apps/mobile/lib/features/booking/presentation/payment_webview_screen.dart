import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/payment_session.dart';
import '../domain/payment_url_policy.dart';

/// PayTR iFrame inside a WebView with a hold countdown.
///
/// A redirect to the merchant result URL (any allowed URL containing `/payment/result`),
/// closing the screen or the countdown reaching zero only means "the attempt is over":
/// the real outcome is read from the booking row on [PaymentResultScreen].
///
/// Hardening: navigation is filtered by [decidePaymentNavigation] (https to `*.paytr.com` and the
/// `PAYMENT_RESULT_BASE_URL` host only), no JavaScript channels are registered, and the page that is
/// loaded first must itself be an https PayTR URL. WebView file access is never used: `file:` URLs are
/// blocked by the same policy.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _loading = true;
  bool _loadFailed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.args.holdExpiresAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // JavaScript must stay on for the PayTR form, but no JavaScriptChannel is ever added,
    // so page scripts cannot call into the app.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            switch (_decide(request.url, isMainFrame: request.isMainFrame)) {
              case PaymentNavigation.allow:
                return NavigationDecision.navigate;
              case PaymentNavigation.finish:
                _finish();
                return NavigationDecision.prevent;
              case PaymentNavigation.block:
                return NavigationDecision.prevent;
            }
          },
          onPageStarted: (url) {
            if (_decide(url, isMainFrame: true) == PaymentNavigation.finish) _finish();
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame != false) {
              setState(() {
                _loading = false;
                _loadFailed = true;
              });
            }
          },
        ),
      );
    if (!_startLoad()) {
      _loading = false;
      _loadFailed = true;
    }
  }

  static PaymentNavigation _decide(String url, {required bool isMainFrame}) => decidePaymentNavigation(
        url,
        isMainFrame: isMainFrame,
        resultBaseUrl: AppConfig.paymentResultBaseUrl,
      );

  /// Loads the PayTR page, but only when the server-provided URL is https on a PayTR host.
  bool _startLoad() {
    final url = widget.args.iframeUrl;
    if (!isTrustedPaymentStartUrl(url)) return false;
    _controller.loadRequest(Uri.parse(url));
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    final remaining = widget.args.holdExpiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _finish();
      return;
    }
    setState(() => _remaining = remaining);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    context.pushReplacement(AppRoutes.result(widget.args.bookingId));
  }

  void _retryLoad() {
    final started = _startLoad();
    setState(() {
      _loading = started;
      _loadFailed = !started;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(S.securePayment),
          leading: IconButton(
            tooltip: S.close,
            icon: const Icon(Icons.close),
            onPressed: _finish,
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: tokens.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: tokens.action),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(child: Text(S.holdCountdown(formatCountdown(_remaining)), style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
            Expanded(
              child: _loadFailed
                  ? ErrorView(message: S.paymentPageLoadFailed, onRetry: _retryLoad)
                  : Stack(
                      children: [
                        WebViewWidget(controller: _controller),
                        if (_loading) const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
