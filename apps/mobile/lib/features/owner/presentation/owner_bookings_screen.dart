import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';
import 'owner_booking_sheets.dart';
import 'owner_common.dart';
import 'owner_providers.dart';

/// "Rezervasyonlar": upcoming bookings of the selected venue with source / status filters.
class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  OwnerBookingFilter _filter = OwnerBookingFilter.all;

  static String _filterLabel(OwnerBookingFilter f) {
    switch (f) {
      case OwnerBookingFilter.all:
        return S.filterAll;
      case OwnerBookingFilter.app:
        return S.filterApp;
      case OwnerBookingFilter.phone:
        return S.filterPhone;
      case OwnerBookingFilter.blocked:
        return S.filterBlocked;
      case OwnerBookingFilter.pending:
        return S.filterPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.ownerTabBookings)),
      body: OwnerVenueScope(
        builder: (context, venue, switcher) => Column(
          children: [
            switcher,
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
                children: [
                  for (final f in OwnerBookingFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s),
                      child: ChoiceChip(
                        label: Text(_filterLabel(f)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _BookingList(venue: venue, filter: _filter)),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.venue, required this.filter});

  final OwnerVenue venue;
  final OwnerBookingFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(ownerUpcomingProvider(venue.id));
    final pitchesAsync = ref.watch(ownerPitchesProvider(venue.id));
    if (bookingsAsync.hasError || pitchesAsync.hasError) {
      final error = bookingsAsync.error ?? pitchesAsync.error!;
      return ErrorView(
        message: AppException.from(error).message,
        onRetry: () {
          ref.invalidate(ownerUpcomingProvider(venue.id));
          ref.invalidate(ownerPitchesProvider(venue.id));
        },
      );
    }
    final bookings = bookingsAsync.valueOrNull;
    final pitches = pitchesAsync.valueOrNull;
    if (bookings == null || pitches == null) return const LoadingView();

    final now = DateTime.now();
    final live = bookings.where((b) => isLiveOwnerBooking(b, now) && b.endsAt.isAfter(now)).toList();
    final items = live.where((b) => matchesOwnerFilter(b, filter, now)).toList();
    final pitchNames = <String, String>{for (final Pitch p in pitches) p.id: p.name};

    Future<void> refresh() async {
      ref.invalidate(ownerUpcomingProvider(venue.id));
      try {
        await ref.read(ownerUpcomingProvider(venue.id).future);
      } catch (_) {
        // The error state is rendered by the list itself.
      }
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 360,
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    message: live.isEmpty ? S.ownerNoUpcoming : S.ownerNoMatchForFilter,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.l),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (context, i) => _BookingTile(booking: items[i], pitchName: pitchNames[items[i].pitchId] ?? S.pitch),
            ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.pitchName});

  final Booking booking;
  final String pitchName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final style = OwnerBookingStyle.of(booking, t);
    final subtitle = isManualBooking(booking) && (booking.customerName ?? '').isNotEmpty
        ? '$pitchName · ${booking.customerName}'
        : '$pitchName · ${ownerSourceLabelOf(booking)}';
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => showOwnerBookingSheet(context, booking: booking, pitchName: pitchName),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: style.striped ? t.neutral : style.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatIstanbulDateWithWeekday(booking.startsAt), style: theme.textTheme.bodySmall),
                    Text(
                      formatTimeRange(booking.startsAt, booking.endsAt),
                      style: numericStyle(context, size: 22, weight: FontWeight.w700, color: t.brand),
                    ),
                    Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!isBlockBooking(booking)) ...[
                const SizedBox(width: AppSpacing.s),
                StatusChip(status: booking.displayStatus(DateTime.now())),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
