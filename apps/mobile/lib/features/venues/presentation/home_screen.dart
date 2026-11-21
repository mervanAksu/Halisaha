import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/venue_summary.dart';
import 'venues_providers.dart';
import 'widgets/venue_card.dart';

/// Centre tab: venue list with search, district chips and optional location sorting.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(locationProvider.notifier).initSilently();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(venueSearchProvider.notifier).state = value.trim();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(venueListProvider);
    try {
      await ref.read(venueListProvider.future);
    } catch (_) {
      // The error state is rendered by the list itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venueListProvider);
    final hasFilters = ref.watch(venueSearchProvider).isNotEmpty || ref.watch(venueDistrictProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.s),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: appInputDecoration(
                context,
                hint: S.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: S.clear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _debounce?.cancel();
                        ref.read(venueSearchProvider.notifier).state = '';
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const _DistrictChips(),
          const _LocationBanner(),
          Expanded(
            child: AsyncValueWidget<List<VenueSummary>>(
              value: venues,
              onRetry: () => ref.invalidate(venueListProvider),
              data: (list) => RefreshIndicator(
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 360,
                            child: EmptyState(
                              icon: Icons.search_off,
                              message: hasFilters ? S.noVenuesForFilter : S.noVenues,
                              actionLabel: hasFilters ? S.clearFilters : null,
                              onAction: hasFilters
                                  ? () {
                                      _searchController.clear();
                                      ref.read(venueSearchProvider.notifier).state = '';
                                      ref.read(venueDistrictProvider.notifier).state = null;
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.l),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.l),
                        itemBuilder: (context, index) {
                          final venue = list[index];
                          return VenueCard(
                            venue: venue,
                            onTap: () => context.push(AppRoutes.venue(venue.id)),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictChips extends ConsumerWidget {
  const _DistrictChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districts = ref.watch(districtsProvider).valueOrNull ?? const <String>[];
    if (districts.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(venueDistrictProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: ChoiceChip(
              label: const Text(S.allDistricts),
              selected: selected == null,
              onSelected: (_) => ref.read(venueDistrictProvider.notifier).state = null,
            ),
          ),
          for (final d in districts)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s),
              child: ChoiceChip(
                label: Text(d),
                selected: selected == d,
                onSelected: (_) => ref.read(venueDistrictProvider.notifier).state = selected == d ? null : d,
              ),
            ),
        ],
      ),
    );
  }
}

/// Invites the user to share location; hidden once a fix exists. Denial never blocks anything.
class _LocationBanner extends ConsumerWidget {
  const _LocationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    if (location.hasFix || location.status == LocationStatus.unknown || location.status == LocationStatus.error) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(locationProvider.notifier);
    final String message;
    final String action;
    final VoidCallback onAction;
    switch (location.status) {
      case LocationStatus.deniedForever:
        message = S.locationDeniedForever;
        action = S.openSettings;
        onAction = notifier.openSettings;
      case LocationStatus.serviceDisabled:
        message = S.locationServiceDisabled;
        action = S.openSettings;
        onAction = notifier.openSettings;
      default:
        message = S.locationPrompt;
        action = S.shareLocation;
        onAction = notifier.request;
    }
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location, size: 20, color: tokens.action),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textPrimary)),
          ),
          if (location.status == LocationStatus.loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
