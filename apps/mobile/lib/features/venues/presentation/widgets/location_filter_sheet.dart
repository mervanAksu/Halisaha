import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/turkish.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/venue_location.dart';
import '../venues_providers.dart';

/// Opens the two-step province / district picker (~85% height, draggable).
Future<void> showLocationFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (context, scrollController) => LocationFilterSheet(scrollController: scrollController),
    ),
  );
}

/// Step 1: pick a province ("İl seç"). Step 2: pick districts of it, then apply.
class LocationFilterSheet extends ConsumerStatefulWidget {
  const LocationFilterSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<LocationFilterSheet> createState() => _LocationFilterSheetState();
}

class _LocationFilterSheetState extends ConsumerState<LocationFilterSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Null = step 1 (province list); set = step 2 (districts of this province).
  String? _city;
  Set<String> _districts = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCity(String city) {
    final current = ref.read(locationFilterProvider);
    setState(() {
      _city = city;
      // Re-opening the active province shows its current selection.
      _districts = current.city == city ? {...current.districts} : <String>{};
    });
  }

  void _backToCities() => setState(() => _city = null);

  Future<void> _clearAndClose() async {
    final navigator = Navigator.of(context);
    await ref.read(locationFilterProvider.notifier).clear();
    navigator.pop();
  }

  Future<void> _applyAndClose() async {
    final navigator = Navigator.of(context);
    await ref.read(locationFilterProvider.notifier).apply(city: _city, districts: _districts);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(venueLocationsProvider);
    return AsyncValueWidget<List<VenueLocation>>(
      value: locations,
      onRetry: () => ref.invalidate(venueLocationsProvider),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(icon: Icons.place_outlined, message: S.noLocations);
        }
        final city = _city;
        return city == null ? _buildCities(context, list) : _buildDistricts(context, list, city);
      },
    );
  }

  // --- Step 1 ------------------------------------------------------------------

  Widget _buildCities(BuildContext context, List<VenueLocation> locations) {
    final active = ref.watch(locationFilterProvider);
    final fold = foldTr(_query.trim());
    final cities = cityOptions(locations).where((c) => fold.isEmpty || foldTr(c.city).contains(fold)).toList();
    final theme = Theme.of(context);
    return Column(
      children: [
        _Header(title: S.selectProvince),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.s),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: appInputDecoration(
              context,
              hint: S.searchProvince,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: S.clear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.xl),
            children: [
              if (fold.isEmpty)
                _PickRow(
                  title: S.locationAll,
                  selected: !active.isActive,
                  onTap: _clearAndClose,
                ),
              for (final c in cities)
                _PickRow(
                  title: c.city,
                  trailingText: S.venueCount(c.venueCount),
                  selected: active.city == c.city,
                  showChevron: true,
                  onTap: () => _openCity(c.city),
                ),
              if (cities.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    S.noProvinceMatch,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 2 ------------------------------------------------------------------

  Widget _buildDistricts(BuildContext context, List<VenueLocation> locations, String city) {
    final options = districtOptions(locations, city);
    final cityTotal = options.fold<int>(0, (sum, d) => sum + d.venueCount);
    final selectedTotal =
        options.where((d) => _districts.contains(d.district)).fold<int>(0, (sum, d) => sum + d.venueCount);
    final count = _districts.isEmpty ? cityTotal : selectedTotal;
    return Column(
      children: [
        _Header(title: S.districtsOf(city), onBack: _backToCities),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
            children: [
              _PickRow(
                title: S.allDistricts,
                trailingText: S.venueCount(cityTotal),
                selected: _districts.isEmpty,
                checkbox: true,
                onTap: () => setState(() => _districts = <String>{}),
              ),
              for (final d in options)
                _PickRow(
                  title: d.district,
                  trailingText: S.venueCount(d.venueCount),
                  selected: _districts.contains(d.district),
                  checkbox: true,
                  onTap: () => setState(() {
                    final next = {..._districts};
                    if (!next.remove(d.district)) next.add(d.district);
                    _districts = next;
                  }),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.l),
          decoration: BoxDecoration(
            color: context.tokens.surface,
            border: Border(top: BorderSide(color: context.tokens.border)),
          ),
          child: SafeArea(
            top: false,
            child: PrimaryButton(label: S.showVenuesCount(count), onPressed: _applyAndClose),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s, 0, AppSpacing.l, AppSpacing.s),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: S.goBack,
              constraints: const BoxConstraints(minWidth: AppSizes.minTarget, minHeight: AppSizes.minTarget),
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            )
          else
            const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable row. Selected rows use the `highlight` fill with `onHighlight` text.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailingText,
    this.checkbox = false,
    this.showChevron = false,
  });

  final String title;
  final String? trailingText;
  final bool selected;
  final bool checkbox;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final fg = selected ? tokens.onHighlight : tokens.textPrimary;
    final fgSecondary = selected ? tokens.onHighlight : tokens.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        checked: checkbox ? selected : null,
        label: trailingText == null ? title : '$title, $trailingText',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: selected ? tokens.highlight : tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.slot),
            side: BorderSide(color: selected ? tokens.highlight : tokens.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                child: Row(
                  children: [
                    if (checkbox) ...[
                      Icon(
                        selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: selected ? tokens.onHighlight : tokens.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: fg,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (trailingText != null)
                      Text(trailingText!, style: theme.textTheme.bodySmall?.copyWith(color: fgSecondary)),
                    if (showChevron) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.chevron_right, color: fgSecondary),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
