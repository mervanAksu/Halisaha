import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/payment_session.dart';

/// PayTR iFrame inside a WebView with a hold countdown.
///
/// A redirect to the merchant result URL (any URL containing `/payment/result`),
/// closing the screen or the countdown reaching zero only means "the attempt is over":
/// the real outcome is read from the booking row on [PaymentResultScreen].
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

  static bool _isResultUrl(String url) => url.contains('/payment/result');

  @override
  void initState() {
    super.initState();
    _remaining = widget.args.holdExpiresAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isResultUrl(request.url)) {
              _finish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (_isResultUrl(url)) _finish();
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
      )
      ..loadRequest(Uri.parse(widget.args.iframeUrl));
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
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    _controller.loadRequest(Uri.parse(widget.args.iframeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: AppColors.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20, color: AppColors.accent),
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
