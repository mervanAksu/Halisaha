import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../venues_providers.dart';
import 'location_filter_sheet.dart';

/// Single button under the search box: pin + current location label, chevron and, while a filter
/// is active, a clear button. Tapping opens [showLocationFilterSheet].
class LocationFilterBar extends ConsumerWidget {
  const LocationFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(locationFilterProvider);
    final tokens = context.tokens;
    final theme = Theme.of(context);
    void open() => showLocationFilterSheet(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.xs),
      child: Material(
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${S.locationFilterSemantics}: ${filter.label}',
                  excludeSemantics: true,
                  onTap: open,
                  child: InkWell(
                    onTap: open,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.l),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, size: 20, color: tokens.action),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                filter.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: tokens.textPrimary,
                                  fontWeight: filter.isActive ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (filter.isActive)
                IconButton(
                  tooltip: S.clearLocationFilter,
                  iconSize: 20,
                  constraints: const BoxConstraints(minWidth: AppSizes.minTarget, minHeight: AppSizes.minTarget),
                  icon: Icon(Icons.close, color: tokens.textSecondary),
                  onPressed: () => ref.read(locationFilterProvider.notifier).clear(),
                ),
              ExcludeSemantics(
                child: InkWell(
                  onTap: open,
                  child: SizedBox(
                    width: 40,
                    height: AppSizes.minTarget,
                    child: Icon(Icons.expand_more, color: tokens.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
