import 'package:flutter/material.dart';

import '../../features/booking/domain/booking.dart';
import '../l10n/strings.dart';
import '../theme/app_tokens.dart';

/// Booking status label (docs/DESIGN.md "Durum etiketi").
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status, context.tokens);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: style.outline ? Border.all(color: style.foreground) : null,
      ),
      child: Text(
        style.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: style.foreground),
      ),
    );
  }

  static _ChipStyle _styleFor(BookingStatus status, AppTokens t) {
    switch (status) {
      case BookingStatus.confirmed:
        return _ChipStyle(S.statusConfirmed, t.accentSoft, t.action);
      case BookingStatus.pendingPayment:
        return _ChipStyle(S.statusPendingPayment, t.warningSoft, t.warning);
      case BookingStatus.cancelled:
        return _ChipStyle(S.statusCancelled, t.dangerSoft, t.danger);
      case BookingStatus.expired:
        return _ChipStyle(S.statusExpired, t.disabledSlot, t.onDisabledSlot);
      case BookingStatus.completed:
        return _ChipStyle(S.statusCompleted, t.disabledSlot, t.onDisabledSlot);
      case BookingStatus.noShow:
        return _ChipStyle(S.statusNoShow, t.transparent, t.danger, outline: true);
    }
  }
}

class _ChipStyle {
  const _ChipStyle(this.label, this.background, this.foreground, {this.outline = false});

  final String label;
  final Color background;
  final Color foreground;
  final bool outline;
}
