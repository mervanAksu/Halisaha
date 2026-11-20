import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/domain/payment_session.dart';
import '../../../booking/presentation/booking_providers.dart';

/// One booking in "Maçlarım", with pay-again and cancel actions for upcoming matches.
class BookingCard extends ConsumerStatefulWidget {
  const BookingCard({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<BookingCard> {
  bool _busy = false;

  Future<void> _continuePayment() async {
    final booking = widget.booking;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final session = await ref.read(bookingRepositoryProvider).startPayment(booking.id);
      if (!mounted) return;
      context.push(
        AppRoutes.payment,
        extra: PaymentArgs(
          bookingId: booking.id,
          iframeUrl: session.iframeUrl,
          holdExpiresAt: session.holdExpiresAt ?? booking.holdExpiresAt ?? DateTime.now(),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      ref.invalidate(myBookingsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final booking = widget.booking;
    final messenger = ScaffoldMessenger.of(context);
    final preview = booking.refundPreview(DateTime.now());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.cancelDialogTitle),
        content: Text(S.cancelPreviewText(preview, booking.cancellationWindowHours ?? defaultCancellationWindowHours)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            child: const Text(S.cancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(bookingRepositoryProvider).cancel(booking.id);
      ref.invalidate(myBookingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(S.cancelResultText(preview, result.refundEligible))));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      ref.invalidate(myBookingsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final status = booking.displayStatus(now);
    final canPay = status == BookingStatus.pendingPayment && booking.endsAt.isAfter(now);
    final canCancel = booking.canCancel(now);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(booking.venueName ?? S.unknownVenue, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.s),
              StatusChip(status: status),
            ],
          ),
          if (booking.venueDistrict != null || booking.pitchName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (booking.pitchName != null) S.pitchLabel(booking.pitchName!, booking.pitchFormat ?? ''),
                if (booking.venueDistrict != null) booking.venueDistrict!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              const Icon(Icons.event, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  '${formatIstanbulDate(booking.startsAt)} · ${formatTimeRange(booking.startsAt, booking.endsAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            S.bookingMoneyLine(formatTry(booking.depositKurus), formatTry(booking.priceKurus)),
            style: theme.textTheme.bodySmall,
          ),
          if (canPay || canCancel) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      child: const Text(S.cancelBooking),
                    ),
                  ),
                if (canPay && canCancel) const SizedBox(width: AppSpacing.m),
                if (canPay)
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _continuePayment,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                            )
                          : const Text(S.continuePayment),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
