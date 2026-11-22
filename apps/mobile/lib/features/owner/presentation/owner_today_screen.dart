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
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import '../../venues/presentation/widgets/date_strip.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';
import 'owner_booking_sheets.dart';
import 'owner_common.dart';
import 'owner_providers.dart';
import 'owner_account_button.dart';

/// "Bugün": date strip and a pitch x time calendar for the selected venue.
class OwnerTodayScreen extends ConsumerStatefulWidget {
  const OwnerTodayScreen({super.key});

  @override
  ConsumerState<OwnerTodayScreen> createState() => _OwnerTodayScreenState();
}

class _OwnerTodayScreenState extends ConsumerState<OwnerTodayScreen> {
  /// Index in the strip: 0 = yesterday, 1 = today's business day, ...
  int _index = 1;
  late final DateTime _businessToday = businessDayToday(DateTime.now());

  DateTime get _date => DateTime.utc(_businessToday.year, _businessToday.month, _businessToday.day + _index - 1);

  void _refresh(String venueId) {
    ref.invalidate(ownerDayBookingsProvider);
    ref.invalidate(ownerPitchesProvider(venueId));
    ref.invalidate(ownerHoursProvider(venueId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.today), actions: const [OwnerAccountButton()]),
      body: OwnerVenueScope(
        builder: (context, venue, switcher) => RefreshIndicator(
          onRefresh: () async => _refresh(venue.id),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              switcher,
              const SizedBox(height: AppSpacing.s),
              // The strip's first chip is yesterday ("Dün"), so owners can review or fix the previous day.
              DateStrip(
                today: _businessToday,
                selectedIndex: _index,
                includeYesterday: true,
                yesterdayLabel: S.yesterday,
                onSelected: (i) => setState(() => _index = i),
              ),
              const SizedBox(height: AppSpacing.s),
              _DayCalendar(venue: venue, date: _date),
              const SizedBox(height: AppSpacing.m),
              const OwnerLegend(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCalendar extends ConsumerWidget {
  const _DayCalendar({required this.venue, required this.date});

  final OwnerVenue venue;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pitchesAsync = ref.watch(ownerPitchesProvider(venue.id));
    final hoursAsync = ref.watch(ownerHoursProvider(venue.id));
    final bookingsAsync = ref.watch(ownerDayBookingsProvider((venueId: venue.id, isoDate: formatIsoDate(date))));

    Object? error;
    for (final a in <AsyncValue<Object?>>[pitchesAsync, hoursAsync, bookingsAsync]) {
      if (a.hasError) error = a.error;
    }
    if (error != null) {
      return SizedBox(
        height: 260,
        child: ErrorView(
          message: AppException.from(error).message,
          onRetry: () {
            ref.invalidate(ownerPitchesProvider(venue.id));
            ref.invalidate(ownerHoursProvider(venue.id));
            ref.invalidate(ownerDayBookingsProvider);
          },
        ),
      );
    }
    final pitches = pitchesAsync.valueOrNull;
    final hours = hoursAsync.valueOrNull;
    final bookings = bookingsAsync.valueOrNull;
    if (pitches == null || hours == null || bookings == null) {
      return const SizedBox(height: 260, child: LoadingView());
    }

    final active = pitches.where((p) => p.isActive).toList();
    if (active.isEmpty) {
      return const SizedBox(height: 260, child: EmptyState(icon: Icons.sports_soccer, message: S.ownerNoPitchesToday));
    }
    final dayHours = hours.firstWhere((h) => h.isoWeekday == date.weekday, orElse: () => DayHours.closed(date.weekday));
    final rows = buildOwnerGrid(
      pitches: active,
      hours: dayHours,
      date: date,
      bookings: bookings,
      now: DateTime.now(),
    );
    if (rows.isEmpty) {
      return const SizedBox(height: 260, child: EmptyState(icon: Icons.event_busy, message: S.ownerClosedDay));
    }
    return OwnerGrid(rows: rows, pitches: active);
  }
}

/// The calendar table: a time column and one column per pitch. Scrolls sideways when the pitches
/// do not fit the screen.
class OwnerGrid extends StatelessWidget {
  const OwnerGrid({super.key, required this.rows, required this.pitches});

  final List<OwnerGridRow> rows;
  final List<Pitch> pitches;

  static const double _timeWidth = 64;
  static const double _minColumn = 104;
  static const double _cellHeight = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _timeWidth - AppSpacing.l * 2;
        final columnWidth = (available / pitches.length) < _minColumn ? _minColumn : available / pitches.length;
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: _timeWidth),
                for (final p in pitches)
                  SizedBox(
                    width: columnWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: _timeWidth,
                      child: Text(
                        formatIstanbulTime(row.start),
                        style: numericStyle(context, size: 18, weight: FontWeight.w700, color: context.tokens.brand),
                      ),
                    ),
                    for (final cell in row.cells)
                      SizedBox(
                        width: columnWidth,
                        height: _cellHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: _GridCell(cell: cell),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: table,
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.cell});

  final OwnerCell cell;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    switch (cell.kind) {
      case OwnerCellKind.none:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.slot),
            border: Border.all(color: t.border),
          ),
        );
      case OwnerCellKind.empty:
        return Material(
          color: cell.isPast ? t.disabledSlot : t.card,
          borderRadius: BorderRadius.circular(AppRadius.slot),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.slot),
            onTap: cell.isPast
                ? null
                : () => showOwnerEmptySlotSheet(context, pitch: cell.pitch, start: cell.start, end: cell.end),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.slot),
                border: Border.all(color: t.border),
              ),
              alignment: Alignment.center,
              child: cell.isPast ? null : Icon(Icons.add, color: t.textSecondary),
            ),
          ),
        );
      case OwnerCellKind.booking:
      case OwnerCellKind.continuation:
        final booking = cell.booking!;
        final style = OwnerBookingStyle.of(booking, t);
        final isFirst = cell.kind == OwnerCellKind.booking;
        return Material(
          color: style.background,
          borderRadius: BorderRadius.circular(AppRadius.slot),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showOwnerBookingSheet(context, booking: booking, pitchName: cell.pitch.name),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.slot),
                border: Border.all(color: style.border),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (style.striped) CustomPaint(painter: StripePainter(style.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xs),
                    child: isFirst ? _BookingLabel(booking: booking, style: style) : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

class _BookingLabel extends StatelessWidget {
  const _BookingLabel({required this.booking, required this.style});

  final Booking booking;
  final OwnerBookingStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final second = isManualBooking(booking) && (booking.customerName ?? '').isNotEmpty
        ? booking.customerName!
        : (booking.status == BookingStatus.noShow
            ? S.notAttended
            : (booking.status == BookingStatus.completed ? S.attended : null));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          style.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(color: style.foreground),
        ),
        if (second != null)
          Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: style.foreground),
          ),
      ],
    );
  }
}
