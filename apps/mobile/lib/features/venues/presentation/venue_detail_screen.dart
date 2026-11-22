import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/network_image_box.dart';
import '../../../core/widgets/primary_button.dart';
import '../../booking/domain/booking_draft.dart';
import '../../favorites/presentation/favorites_providers.dart';
import '../domain/pitch.dart';
import '../domain/slot.dart';
import '../domain/slot_groups.dart';
import '../domain/venue_detail.dart';
import 'venues_providers.dart';
import 'widgets/date_strip.dart';
import 'widgets/slot_grid.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  String? _pitchId;
  int _dayIndex = 0;
  DateTime? _selectedStart;
  late final DateTime _today = istanbulToday();

  /// Before 06:00 (Istanbul) yesterday's business day is still open for overnight venues.
  late final bool _includeYesterday = toIstanbul(DateTime.now()).hour < 6;

  int get _dayOffset => _dayIndex - (_includeYesterday ? 1 : 0);

  Pitch _effectivePitch(VenueDetail venue) {
    for (final p in venue.pitches) {
      if (p.id == _pitchId) return p;
    }
    return venue.pitches.first;
  }

  Future<void> _toggleFavorite(bool currentlyFavorite) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(favoritesActionsProvider).setFavorite(widget.venueId, favorite: !currentlyFavorite);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueDetailProvider(widget.venueId));
    final favoriteIds = ref.watch(favoriteIdsProvider).valueOrNull ?? const <String>{};
    final isFavorite = favoriteIds.contains(widget.venueId);
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.venueDetailTitle),
        actions: [
          IconButton(
            tooltip: isFavorite ? S.removeFavorite : S.addFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? context.tokens.danger : null,
            ),
            onPressed: () => _toggleFavorite(isFavorite),
          ),
        ],
      ),
      body: AsyncValueWidget<VenueDetail>(
        value: venue,
        onRetry: () => ref.invalidate(venueDetailProvider(widget.venueId)),
        data: (v) => _buildBody(context, v),
      ),
      bottomNavigationBar: venue.valueOrNull == null || venue.valueOrNull!.pitches.isEmpty
          ? null
          : _buildSummaryBar(venue.valueOrNull!),
    );
  }

  AvailabilityKey _key(Pitch pitch) {
    final date = DateTime.utc(_today.year, _today.month, _today.day + _dayOffset);
    return (pitchId: pitch.id, isoDate: formatIsoDate(date));
  }

  Slot? _selectedSlot(VenueDetail venue) {
    if (venue.pitches.isEmpty || _selectedStart == null) return null;
    final slots = ref.watch(availabilityProvider(_key(_effectivePitch(venue)))).valueOrNull;
    if (slots == null) return null;
    for (final s in slots) {
      if (s.startsAt.isAtSameMomentAs(_selectedStart!) && s.isAvailable) return s;
    }
    return null;
  }

  /// Sticky bar under the slot picker: selected time, total and the deposit due now.
  Widget _buildSummaryBar(VenueDetail venue) {
    final slot = _selectedSlot(venue);
    final pitch = _effectivePitch(venue);
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: slot == null
                    ? Text(S.selectSlotHint, style: theme.textTheme.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatIstanbulDateWithWeekday(slot.startsAt), style: theme.textTheme.bodySmall),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formatTimeRange(slot.startsAt, slot.endsAt),
                                style: numericStyle(context, size: 24, weight: FontWeight.w700, color: tokens.brand),
                              ),
                              const SizedBox(width: AppSpacing.m),
                              Flexible(
                                child: Text(
                                  S.summaryTotal(formatTry(slot.priceKurus)),
                                  style: numericStyle(context, size: 18, weight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            S.summaryDepositNow(formatTry(slot.depositKurus)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.action,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: AppSpacing.l),
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  label: S.continueLabel,
                  onPressed: slot == null
                      ? null
                      : () => context.push(
                            AppRoutes.bookingSummary,
                            extra: BookingDraft(
                              venueId: venue.id,
                              venueName: venue.name,
                              district: venue.district,
                              cancellationWindowHours: venue.cancellationWindowHours,
                              pitchId: pitch.id,
                              pitchName: pitch.name,
                              pitchFormat: pitch.format,
                              slot: slot,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VenueDetail venue) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _PhotoGallery(paths: venue.galleryPaths, venueName: venue.name),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(venue.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              // Only venues with status=active are readable by customers (RLS), so every venue shown is verified.
              Row(
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: tokens.action),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    S.verifiedVenue,
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.action, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on_outlined, size: 18, color: tokens.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      venue.addressLine,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openExternalOrWarn(
                    context,
                    mapsUrl(lat: venue.lat, lng: venue.lng, query: '${venue.name} ${venue.address} ${venue.district} ${venue.city}'),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(S.openInMaps),
                ),
              ),
              if (venue.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Text(venue.description, style: theme.textTheme.bodyMedium),
              ],
              if (venue.amenities.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.l),
                Text(S.amenities, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: [
                    for (final a in venue.amenities)
                      Chip(
                        label: Text(S.amenityLabel(a)),
                        backgroundColor: tokens.accentSoft,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (venue.pitches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(S.noPitches, style: theme.textTheme.bodySmall),
          )
        else
          ..._buildBooking(context, venue),
      ],
    );
  }

  List<Widget> _buildBooking(BuildContext context, VenueDetail venue) {
    final theme = Theme.of(context);
    final pitch = _effectivePitch(venue);
    final key = _key(pitch);
    final availability = ref.watch(availabilityProvider(key));
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Text(S.selectPitch, style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: AppSpacing.s),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final p in venue.pitches)
              ChoiceChip(
                label: Text(S.pitchLabel(p.name, p.format)),
                selected: p.id == pitch.id,
                onSelected: (_) => setState(() {
                  _pitchId = p.id;
                  _selectedStart = null;
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.l),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Text(S.selectDate, style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: AppSpacing.s),
      DateStrip(
        today: _today,
        selectedIndex: _dayIndex,
        includeYesterday: _includeYesterday,
        onSelected: (i) => setState(() {
          _dayIndex = i;
          _selectedStart = null;
        }),
      ),
      const SizedBox(height: AppSpacing.l),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Text(S.selectTime, style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: AppSpacing.s),
      availability.when(
        loading: () => const SizedBox(height: 120, child: LoadingView()),
        error: (e, _) => SizedBox(
          height: 220,
          child: ErrorView(
            message: AppException.from(e).message,
            onRetry: () => ref.invalidate(availabilityProvider(key)),
          ),
        ),
        data: (slots) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasAvailableSlot(slots))
              _EmptyDay(
                pitchId: pitch.id,
                fromIsoDate: key.isoDate,
                maxDays: (dateStripDays - 1) - _dayOffset,
                onJump: (day) => setState(() {
                  _dayIndex = day.difference(_today).inDays + (_includeYesterday ? 1 : 0);
                  _selectedStart = null;
                }),
              ),
            SlotGrid(
              slots: slots,
              selectedStart: _selectedStart,
              onSelected: (slot) => setState(() => _selectedStart = slot.startsAt),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, 0),
        child: Text(S.depositNote(formatTry(pitch.depositKurus)), style: theme.textTheme.bodySmall),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.xs, AppSpacing.l, 0),
        child: Text(S.cancellationPolicyShort(venue.cancellationWindowHours), style: theme.textTheme.bodySmall),
      ),
    ];
  }
}

/// "Bu tarihte müsait saat yok" with a button that jumps to the nearest later day that has a free slot.
class _EmptyDay extends ConsumerWidget {
  const _EmptyDay({
    required this.pitchId,
    required this.fromIsoDate,
    required this.maxDays,
    required this.onJump,
  });

  final String pitchId;
  final String fromIsoDate;
  final int maxDays;
  final ValueChanged<DateTime> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final Widget action;
    if (maxDays <= 0) {
      action = Text(S.noSlotsNearby, style: theme.textTheme.bodySmall, textAlign: TextAlign.center);
    } else {
      final nearest = ref.watch(nearestAvailableDayProvider((pitchId: pitchId, fromIsoDate: fromIsoDate, maxDays: maxDays)));
      action = nearest.when(
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.s),
            Text(S.searchingNearestDay, style: theme.textTheme.bodySmall),
          ],
        ),
        error: (_, __) => Text(S.noSlotsNearby, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        data: (day) => day == null
            ? Text(S.noSlotsNearby, style: theme.textTheme.bodySmall, textAlign: TextAlign.center)
            : PrimaryButton(
                label: S.nearestFreeDay(formatWeekdayLong(day)),
                icon: Icons.event_available,
                expand: false,
                onPressed: () => onJump(day),
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.m),
      child: Column(
        children: [
          Text(S.noSlots, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.m),
          action,
        ],
      ),
    );
  }
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.paths, required this.venueName});

  final List<String> paths;
  final String venueName;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    final tokens = context.tokens;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (paths.isEmpty)
            NetworkImageBox(url: null, title: widget.venueName)
          else
            PageView.builder(
              itemCount: paths.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => NetworkImageBox(url: venuePhotoUrl(paths[i]), title: widget.venueName),
            ),
          if (paths.length > 1)
            Positioned(
              bottom: AppSpacing.m,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < paths.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? tokens.onPrimary : tokens.overlay,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
