import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// Number of days offered in the strip (PRD M3: 14-day date strip).
const int dateStripDays = 14;

/// Horizontal 14-day strip starting today (Istanbul). [selectedIndex] is 0..13.
class DateStrip extends StatelessWidget {
  const DateStrip({super.key, required this.today, required this.selectedIndex, required this.onSelected});

  /// Today's Istanbul calendar date (see `istanbulToday`).
  final DateTime today;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: dateStripDays,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, index) {
          final date = DateTime.utc(today.year, today.month, today.day + index);
          final selected = index == selectedIndex;
          final fg = selected ? AppColors.onPrimary : AppColors.textPrimary;
          final fgSecondary = selected ? AppColors.onPrimary : AppColors.textSecondary;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.button),
            onTap: () => onSelected(index),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    index == 0 ? S.today : formatWeekdayShort(date),
                    style: theme.textTheme.bodySmall?.copyWith(color: fgSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
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
