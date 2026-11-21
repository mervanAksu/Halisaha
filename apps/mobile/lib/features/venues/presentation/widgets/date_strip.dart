import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';

/// Number of days offered in the strip (PRD M3: 14-day date strip).
const int dateStripDays = 14;

/// Horizontal 14-day strip starting today (Istanbul). [selectedIndex] is 0..13.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.today,
    required this.selectedIndex,
    required this.onSelected,
    this.includeYesterday = false,
    this.yesterdayLabel = S.lastNight,
  });

  /// Today's Istanbul calendar date (see `istanbulToday`).
  final DateTime today;

  /// Before 06:00 Istanbul time the previous business day is still running (overnight venues):
  /// it is offered as the first chip ("Dün gece").
  final bool includeYesterday;

  /// Label of the yesterday chip: "Dün gece" for customers (only shown before 06:00), "Dün" for owners.
  final String yesterdayLabel;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0).toDouble();
    return SizedBox(
      height: 84 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: dateStripDays + (includeYesterday ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, index) {
          final offset = index - (includeYesterday ? 1 : 0);
          final date = DateTime.utc(today.year, today.month, today.day + offset);
          final selected = index == selectedIndex;
          final fg = selected ? tokens.onPrimary : tokens.textPrimary;
          final fgSecondary = selected ? tokens.onPrimary : tokens.textSecondary;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.button),
            onTap: () => onSelected(index),
            child: Container(
              width: 60 * (scale > 1.6 ? 1.6 : scale),
              decoration: BoxDecoration(
                color: selected ? tokens.primary : tokens.card,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: selected ? tokens.primary : tokens.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    offset == -1 ? yesterdayLabel : (offset == 0 ? S.today : formatWeekdayShort(date)),
                    style: theme.textTheme.bodySmall?.copyWith(color: fgSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: numericStyle(context, size: 22, weight: FontWeight.w700, color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMonthShort(date),
                    style: theme.textTheme.bodySmall?.copyWith(color: fgSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
