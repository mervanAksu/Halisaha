import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? AppColors.danger : null),
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
          : _buildBottomBar(venue.valueOrNull!),
    );
  }

  AvailabilityKey _key(Pitch pitch) {
    final date = DateTime.utc(_today.year, _today.month, _today.day + _dayIndex);
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

  Widget _buildBottomBar(VenueDetail venue) {
    final slot = _selectedSlot(venue);
    final pitch = _effectivePitch(venue);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: slot == null
                    ? Text(S.selectSlotHint, style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatIstanbulDate(slot.startsAt), style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            formatTimeRange(slot.startsAt, slot.endsAt),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: AppSpacing.l),
              SizedBox(
                width: 160,
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
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _PhotoGallery(paths: venue.galleryPaths),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(venue.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      venue.address.isEmpty ? venue.district : '${venue.address}, ${venue.district}',
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
                    mapsUrl(lat: venue.lat, lng: venue.lng, query: '${venue.name} ${venue.address} ${venue.district}'),
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
                        backgroundColor: AppColors.accentSoft,
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
    final availability = ref.watch(availabilityProvider(_key(pitch)));
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
            onRetry: () => ref.invalidate(availabilityProvider(_key(pitch))),
          ),
        ),
        data: (slots) => SlotGrid(
          slots: slots,
          selectedStart: _selectedStart,
          onSelected: (slot) => setState(() => _selectedStart = slot.startsAt),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, 0),
        child: Text(S.depositNote(formatTry(pitch.depositKurus)), style: theme.textTheme.bodySmall),
      ),
    ];
  }
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.paths});

  final List<String> paths;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (paths.isEmpty)
            const NetworkImageBox(url: null)
          else
            PageView.builder(
              itemCount: paths.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => NetworkImageBox(url: venuePhotoUrl(paths[i])),
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
                        color: i == _page ? AppColors.onPrimary : AppColors.overlay,
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
