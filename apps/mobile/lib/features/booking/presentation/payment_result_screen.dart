import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/urls.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/booking.dart';
import '../domain/payment_session.dart';
import 'booking_providers.dart';

/// Decides success / failure purely from the booking status in the database.
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poll = ref.watch(paymentPollProvider(bookingId));
    final tokens = context.tokens;

    ref.listen<AsyncValue<PaymentPoll>>(paymentPollProvider(bookingId), (previous, next) {
      final value = next.valueOrNull;
      if (value != null && (value.isDecided || value.timedOut)) {
        ref.invalidate(myBookingsProvider);
      }
    });

    final value = poll.valueOrNull;
    final Widget body;
    if (value == null) {
      body = poll.hasError
          ? _Message(
              icon: Icons.error_outline,
              color: tokens.danger,
              title: S.resultErrorTitle,
              text: AppException.from(poll.error!).message,
              actions: [
                PrimaryButton(label: S.retry, onPressed: () => ref.invalidate(paymentPollProvider(bookingId))),
                _secondary(context, S.goToMatches, () => context.go(AppRoutes.matches)),
              ],
            )
          : const _Checking();
    } else if (value.isDecided) {
      final booking = value.booking!;
      switch (value.outcome) {
        case PaymentOutcome.success:
          body = _Message(
            icon: Icons.check_circle_outline,
            color: tokens.action,
            title: S.paymentSuccessTitle,
            text: S.paymentSuccessBody,
            extra: _BookingSummary(booking: booking),
            actions: [
              PrimaryButton(label: S.goToMatches, onPressed: () => context.go(AppRoutes.matches)),
              _secondary(context, S.goHome, () => context.go(AppRoutes.home)),
            ],
          );
        case PaymentOutcome.refund:
          body = _Message(
            icon: Icons.info_outline,
            color: tokens.warning,
            title: S.paymentRefundTitle,
            text: S.paymentRefundBody,
            actions: [
              PrimaryButton(label: S.goToMatches, onPressed: () => context.go(AppRoutes.matches)),
              _secondary(context, S.goHome, () => context.go(AppRoutes.home)),
            ],
          );
        case PaymentOutcome.failed:
        case PaymentOutcome.checking:
          // A failed attempt on a still-live hold can be retried without picking a new slot.
          final holdAlive = booking.status == BookingStatus.pendingPayment &&
              booking.holdExpiresAt != null &&
              booking.holdExpiresAt!.isAfter(DateTime.now());
          body = _Message(
            icon: Icons.cancel_outlined,
            color: tokens.danger,
            title: S.paymentFailedTitle,
            text: S.paymentFailedBody,
            actions: [
              if (holdAlive)
                PrimaryButton(label: S.retryPayment, onPressed: () => _resumePayment(context, ref, booking))
              else
                PrimaryButton(label: S.tryAgain, onPressed: () => context.go(AppRoutes.venue(booking.venueId))),
              _secondary(context, S.goToMatches, () => context.go(AppRoutes.matches)),
            ],
          );
      }
    } else if (value.timedOut) {
      body = _Message(
        icon: Icons.hourglass_bottom,
        color: tokens.warning,
        title: S.paymentStillPendingTitle,
        text: S.paymentStillPendingBody,
        actions: [
          PrimaryButton(label: S.checkAgain, onPressed: () => ref.invalidate(paymentPollProvider(bookingId))),
          _secondary(context, S.goToMatches, () => context.go(AppRoutes.matches)),
        ],
      );
    } else {
      body = _Checking(onLeave: () => context.go(AppRoutes.matches));
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text(S.paymentResultTitle), automaticallyImplyLeading: false),
        body: SafeArea(child: body),
      ),
    );
  }

  static Future<void> _resumePayment(BuildContext context, WidgetRef ref, Booking booking) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final session = await ref.read(bookingRepositoryProvider).startPayment(booking.id);
      router.pushReplacement(
        AppRoutes.payment,
        extra: PaymentArgs(
          bookingId: booking.id,
          iframeUrl: session.iframeUrl,
          holdExpiresAt: session.holdExpiresAt ?? booking.holdExpiresAt ?? DateTime.now(),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static Widget _secondary(BuildContext context, String label, VoidCallback onPressed) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _Checking extends StatelessWidget {
  const _Checking({this.onLeave});

  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            Text(S.paymentChecking, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s),
            Text(S.paymentCheckingHint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            if (onLeave != null) ...[
              const SizedBox(height: AppSpacing.xl),
              TextButton(onPressed: onLeave, child: const Text(S.goToMatches)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.actions,
    this.extra,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: AppSpacing.l),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (extra != null) ...[const SizedBox(height: AppSpacing.xl), extra!],
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.m),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirmation details: weekday + date, time, tappable address (opens Maps), the deposit that was
/// paid, the remainder due at the venue and the cancellation policy.
class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.booking});

  final Booking booking;

  String? get _addressLine {
    final address = booking.venueAddress;
    final district = booking.venueDistrict;
    final parts = <String>[
      if (address != null && address.isNotEmpty) address,
      if (district != null && district.isNotEmpty) district,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final addressLine = _addressLine;
    final mapQuery = '${booking.venueName ?? ''} ${addressLine ?? ''}'.trim();
    final hasLocation = booking.venueLat != null && booking.venueLng != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking.venueName ?? '', style: theme.textTheme.titleMedium),
          if (booking.pitchName != null)
            Text(S.pitchLabel(booking.pitchName!, booking.pitchFormat ?? ''), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.s),
          Text(formatIstanbulDateWithWeekday(booking.startsAt), style: theme.textTheme.bodyMedium),
          Text(
            formatTimeRange(booking.startsAt, booking.endsAt),
            style: numericStyle(context, size: 24, weight: FontWeight.w700, color: tokens.brand),
          ),
          if (addressLine != null || hasLocation) ...[
            const SizedBox(height: AppSpacing.s),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.button),
              onTap: () => openExternalOrWarn(
                context,
                mapsUrl(lat: booking.venueLat, lng: booking.venueLng, query: mapQuery),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20, color: tokens.action),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        addressLine ?? S.openInMaps,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.action,
                          decoration: TextDecoration.underline,
                          decorationColor: tokens.action,
                        ),
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 16, color: tokens.action),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: AppSpacing.xl),
          if (booking.depositKurus > 0)
            _MoneyRow(label: S.paidDeposit, kurus: booking.depositKurus, color: tokens.action),
          _MoneyRow(label: S.remainderAtVenue, kurus: booking.remainderKurus),
          const SizedBox(height: AppSpacing.s),
          Text(
            S.cancellationPolicyShort(booking.cancellationWindowHours ?? defaultCancellationWindowHours),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.kurus, this.color});

  final String label;
  final int kurus;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(formatTry(kurus), style: numericStyle(context, size: 20, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
