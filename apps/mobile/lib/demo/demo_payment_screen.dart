import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/errors/app_exception.dart';
import '../core/l10n/strings.dart';
import '../core/router/app_routes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/primary_button.dart';
import '../features/booking/domain/payment_session.dart';
import 'demo_overrides.dart';

/// Stand-in for the PayTR WebView in demo mode: no card form, no network. The buttons play the
/// provider callback against the in-memory store; the result screen then reads the booking status.
class DemoPaymentScreen extends ConsumerStatefulWidget {
  const DemoPaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  ConsumerState<DemoPaymentScreen> createState() => _DemoPaymentScreenState();
}

class _DemoPaymentScreenState extends ConsumerState<DemoPaymentScreen> {
  bool _busy = false;

  Future<void> _settle({required bool success}) async {
    final store = ref.read(demoStoreProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      store.settlePayment(widget.args.bookingId, success: success);
      if (!mounted) return;
      router.pushReplacement(AppRoutes.result(widget.args.bookingId));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final store = ref.watch(demoStoreProvider);
    int? deposit;
    try {
      deposit = store.fetchBooking(widget.args.bookingId).depositKurus;
    } on AppException {
      deposit = null;
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.demoPaymentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Icon(Icons.credit_card, size: 64, color: tokens.brand),
            const SizedBox(height: AppSpacing.l),
            Text(S.demoPaymentIntro, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(S.demoPaymentDeposit, style: theme.textTheme.bodyMedium)),
                  Text(
                    deposit == null ? '-' : formatTry(deposit),
                    style: numericStyle(context, size: 22, weight: FontWeight.w700, color: tokens.action),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: S.demoPaymentComplete,
              loading: _busy,
              onPressed: _busy ? null : () => _settle(success: true),
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton(
              onPressed: _busy ? null : () => _settle(success: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.danger,
                side: BorderSide(color: tokens.danger),
              ),
              child: const Text(S.demoPaymentFail),
            ),
          ],
        ),
      ),
    );
  }
}
