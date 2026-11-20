import 'package:flutter/material.dart';

import '../../features/booking/domain/booking.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

/// Booking status label (docs/DESIGN.md "Durum etiketi").
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
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

  static _ChipStyle _styleFor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return const _ChipStyle(S.statusConfirmed, AppColors.accentSoft, AppColors.accent);
      case BookingStatus.pendingPayment:
        return const _ChipStyle(S.statusPendingPayment, AppColors.warningSoft, AppColors.warning);
      case BookingStatus.cancelled:
        return const _ChipStyle(S.statusCancelled, AppColors.dangerSoft, AppColors.danger);
      case BookingStatus.expired:
        return const _ChipStyle(S.statusExpired, AppColors.neutralSoft, AppColors.textSecondary);
      case BookingStatus.completed:
        return const _ChipStyle(S.statusCompleted, AppColors.neutralSoft, AppColors.textSecondary);
      case BookingStatus.noShow:
        return const _ChipStyle(S.statusNoShow, AppColors.transparent, AppColors.danger, outline: true);
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
