import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/primary_button.dart';
import '../../venues/presentation/venues_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_draft.dart';
import '../domain/payment_session.dart';
import 'booking_providers.dart';

/// Hold length used only as a fallback when the server omits `hold_expires_at` (ADR-5: 10 min).
const Duration _fallbackHold = Duration(minutes: 10);

class BookingSummaryScreen extends ConsumerStatefulWidget {
  const BookingSummaryScreen({super.key, required this.draft});

  final BookingDraft draft;

  @override
  ConsumerState<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  bool _acceptedContract = false;
  bool _busy = false;
  String? _error;

  /// Kept after the hold succeeds so a payment retry reuses it instead of creating a second hold.
  Booking? _hold;

  Future<void> _submit() async {
    final draft = widget.draft;
    final repo = ref.read(bookingRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var hold = _hold;
      if (hold == null) {
        hold = await repo.createHold(pitchId: draft.pitchId, startsAt: draft.slot.startsAt);
        _hold = hold;
        ref.invalidate(myBookingsProvider);
        ref.invalidate(availabilityProvider);
      }
      if (!mounted) return;

      if (hold.status == BookingStatus.confirmed) {
        // Zero deposit: nothing to pay. The result screen still confirms from the backend row.
        context.pushReplacement(AppRoutes.result(hold.id));
        return;
      }

      final session = await repo.startPayment(hold.id);
      if (!mounted) return;
      context.push(
        AppRoutes.payment,
        extra: PaymentArgs(
          bookingId: hold.id,
          iframeUrl: session.iframeUrl,
          holdExpiresAt: session.holdExpiresAt ?? hold.holdExpiresAt ?? DateTime.now().add(_fallbackHold),
        ),
      );
    } on AppException catch (e) {
      if (e.code == 'hold_expired') _hold = null;
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final slot = draft.slot;
    final theme = Theme.of(context);
    final remainder = slot.priceKurus - slot.depositKurus;
    final zeroDeposit = slot.depositKurus == 0;
    return Scaffold(
      appBar: AppBar(title: const Text(S.bookingSummaryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          _Card(
            children: [
              Text(draft.venueName, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(draft.district, style: theme.textTheme.bodySmall),
              const Divider(height: AppSpacing.xl),
              _Line(label: S.pitch, value: S.pitchLabel(draft.pitchName, draft.pitchFormat)),
              _Line(label: S.date, value: formatIstanbulDateWithWeekday(slot.startsAt)),
              _Line(label: S.time, value: formatTimeRange(slot.startsAt, slot.endsAt)),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _Card(
            children: [
              _Line(label: S.totalPrice, value: formatTry(slot.priceKurus)),
              _Line(
                label: S.depositNow,
                value: formatTry(slot.depositKurus),
                emphasize: true,
              ),
              _Line(label: S.remainderAtVenue, value: formatTry(remainder)),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          if (!zeroDeposit)
            _InfoBox(icon: Icons.timer_outlined, text: S.holdInfo),
          if (!zeroDeposit) const SizedBox(height: AppSpacing.m),
          _InfoBox(icon: Icons.policy_outlined, title: S.cancellationPolicyTitle, text: S.cancellationPolicy(draft.cancellationWindowHours)),
          const SizedBox(height: AppSpacing.l),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acceptedContract,
            onChanged: _busy ? null : (v) => setState(() => _acceptedContract = v ?? false),
            title: Text(S.distanceSalesCheckbox, style: theme.textTheme.bodyMedium),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                onPressed: () => openExternalOrWarn(context, AppConfig.legalUrl(AppConfig.legalDistanceSales)),
                child: const Text(S.distanceSalesReadLink),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(child: Text(_error!, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: zeroDeposit ? S.confirmBooking : S.proceedToPayment(formatTry(slot.depositKurus)),
            loading: _busy,
            onPressed: _acceptedContract ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = emphasize
        ? theme.textTheme.titleMedium?.copyWith(color: AppColors.accent)
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))),
          const SizedBox(width: AppSpacing.m),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: valueStyle)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(text, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
