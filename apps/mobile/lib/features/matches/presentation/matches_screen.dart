import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_providers.dart';
import 'widgets/booking_card.dart';

/// "Maçlarım": Gelecek / Geçmiş tabs over the user's bookings.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(S.navMatches),
          actions: [
            IconButton(
              tooltip: S.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(myBookingsProvider),
            ),
          ],
          bottom: TabBar(
            labelColor: context.tokens.brand,
            unselectedLabelColor: context.tokens.textSecondary,
            indicatorColor: context.tokens.accent,
            tabs: const [
              Tab(text: S.tabUpcoming),
              Tab(text: S.tabPast),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingList(upcoming: true),
            _BookingList(upcoming: false),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.upcoming});

  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    return AsyncValueWidget<List<Booking>>(
      value: bookings,
      onRetry: () => ref.invalidate(myBookingsProvider),
      data: (all) {
        final now = DateTime.now();
        final items = all.where((b) => b.isUpcoming(now) == upcoming).toList()
          ..sort((a, b) => upcoming ? a.startsAt.compareTo(b.startsAt) : b.startsAt.compareTo(a.startsAt));
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myBookingsProvider);
            try {
              await ref.read(myBookingsProvider.future);
            } catch (_) {
              // Error state is rendered by the list.
            }
          },
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: 420,
                      child: EmptyState(
                        icon: upcoming ? Icons.sports_soccer : Icons.history,
                        message: upcoming ? S.noUpcomingMatches : S.noPastMatches,
                        actionLabel: S.searchVenue,
                        onAction: () => context.go(AppRoutes.home),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
                  itemBuilder: (context, index) => BookingCard(booking: items[index]),
                ),
        );
      },
    );
  }
}
