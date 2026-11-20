import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/slot.dart';

/// 3-column slot grid (docs/DESIGN.md): available = white + accent border,
/// selected = accentSoft, booked = grey + strikethrough, past = hidden.
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.selectedStart, required this.onSelected});

  final List<Slot> slots;
  final DateTime? selectedStart;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = slots.where((s) => s.state != SlotState.past).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            S.noSlots,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s,
      crossAxisSpacing: AppSpacing.s,
      childAspectRatio: 1.8,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        for (final slot in visible)
          _SlotCell(
            slot: slot,
            selected: selectedStart != null && slot.startsAt.isAtSameMomentAs(selectedStart!),
            onTap: slot.isAvailable ? () => onSelected(slot) : null,
          ),
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({required this.slot, required this.selected, required this.onTap});

  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booked = !slot.isAvailable;
    final Color background = booked ? AppColors.neutralSoft : (selected ? AppColors.accentSoft : AppColors.card);
    final Color borderColor = booked ? AppColors.border : AppColors.accent;
    final Color textColor = booked ? AppColors.textSecondary : AppColors.textPrimary;
    final decoration = booked ? TextDecoration.lineThrough : TextDecoration.none;
    return Semantics(
      button: !booked,
      selected: selected,
      label: booked ? S.slotBookedLabel(formatTimeRange(slot.startsAt, slot.endsAt)) : formatTimeRange(slot.startsAt, slot.endsAt),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTimeRange(slot.startsAt, slot.endsAt),
                style: theme.textTheme.labelMedium?.copyWith(color: textColor, decoration: decoration),
              ),
              const SizedBox(height: 2),
              Text(
                formatTry(slot.priceKurus),
                style: theme.textTheme.bodySmall?.copyWith(color: textColor, decoration: decoration),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
