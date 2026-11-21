import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/slot.dart';
import '../../domain/slot_groups.dart';

/// Slot picker (docs/DESIGN.md "Bileşen kuralları"): slots grouped Akşam / Öğleden sonra / Sabah-Gece,
/// 3 columns (2 when the text scale is above 1.3), every cell at least 48 dp high.
/// Available = card + action border, selected = accentSoft, booked = grey with a "Dolu" label
/// (no strikethrough), past = hidden.
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.selectedStart, required this.onSelected});

  final List<Slot> slots;
  final DateTime? selectedStart;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) {
    final groups = groupSlots(slots);
    if (groups.isEmpty) return const SizedBox.shrink();
    final columns = slotGridColumns(MediaQuery.textScalerOf(context).scale(1));
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s, bottom: AppSpacing.s),
              child: Text(S.slotPeriodLabel(group.period), style: theme.textTheme.titleMedium),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - (columns - 1) * AppSpacing.s) / columns;
                return Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: [
                    for (final slot in group.slots)
                      SizedBox(
                        width: cellWidth,
                        child: _SlotCell(
                          slot: slot,
                          selected: selectedStart != null && slot.startsAt.isAtSameMomentAs(selectedStart!),
                          onTap: slot.isAvailable ? () => onSelected(slot) : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
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
    final tokens = context.tokens;
    final booked = !slot.isAvailable;
    final Color background = booked ? tokens.disabledSlot : (selected ? tokens.accentSoft : tokens.card);
    final Color borderColor = booked ? tokens.border : (selected ? tokens.accent : tokens.action);
    final Color textColor = booked ? tokens.onDisabledSlot : tokens.textPrimary;
    final range = formatTimeRange(slot.startsAt, slot.endsAt);
    return Semantics(
      button: !booked,
      selected: selected,
      label: booked ? S.slotBookedLabel(range) : range,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.slot),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.slot),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(range, style: numericStyle(context, size: 17, weight: FontWeight.w700, color: textColor)),
              Text(
                booked ? S.slotBooked : formatTry(slot.priceKurus),
                style: numericStyle(context, size: 14, weight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
