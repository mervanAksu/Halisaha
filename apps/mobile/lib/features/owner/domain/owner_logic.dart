import '../../../core/utils/formatters.dart';
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import 'owner_models.dart';

/// First hour (Istanbul) of a new business day: before 06:00 the previous day is still running.
const int businessDayStartHour = 6;

/// Today's business day as an Istanbul calendar date (midnight, UTC-flagged wall clock).
/// Before 06:00 Istanbul time it is still "yesterday" (overnight venues are open past midnight).
DateTime businessDayToday(DateTime now) {
  final wall = toIstanbul(now);
  final day = DateTime.utc(wall.year, wall.month, wall.day);
  return wall.hour < businessDayStartHour ? day.subtract(const Duration(days: 1)) : day;
}

/// UTC window that holds every booking of the business day [date]:
/// 00:00 of the day up to 06:00 of the next day (Istanbul).
({DateTime fromUtc, DateTime toUtc}) ownerDayWindow(DateTime date) {
  final from = DateTime.utc(date.year, date.month, date.day).subtract(istanbulOffset);
  final to = DateTime.utc(date.year, date.month, date.day + 1, businessDayStartHour).subtract(istanbulOffset);
  return (fromUtc: from, toUtc: to);
}

/// Slot start instants (UTC) of one pitch on the business day [date] (Istanbul wall-clock date).
/// Empty when the day is closed. An overnight day runs into the next calendar day.
List<DateTime> ownerSlotStarts({required DateTime date, required DayHours? hours, required int slotMinutes}) {
  if (hours == null || hours.closed || slotMinutes <= 0) return const [];
  final midnightAsUtc = DateTime.utc(date.year, date.month, date.day);
  final open = midnightAsUtc.add(Duration(minutes: hours.openMinutes)).subtract(istanbulOffset);
  var close = midnightAsUtc.add(Duration(minutes: hours.closeMinutes)).subtract(istanbulOffset);
  if (hours.closeMinutes <= hours.openMinutes) close = close.add(const Duration(days: 1));
  final step = Duration(minutes: slotMinutes);
  final starts = <DateTime>[];
  for (var start = open; !start.add(step).isAfter(close); start = start.add(step)) {
    starts.add(start);
  }
  return starts;
}

/// Bookings that occupy the calendar: confirmed ones, finished ones, and unpaid holds that are still alive.
bool isLiveOwnerBooking(Booking b, DateTime now) {
  switch (b.status) {
    case BookingStatus.confirmed:
    case BookingStatus.completed:
    case BookingStatus.noShow:
      return true;
    case BookingStatus.pendingPayment:
      return b.holdExpiresAt != null && b.holdExpiresAt!.isAfter(now);
    case BookingStatus.cancelled:
    case BookingStatus.expired:
      return false;
  }
}

bool isAppBooking(Booking b) => b.source == 'app';
bool isManualBooking(Booking b) => b.source == 'manual';
bool isBlockBooking(Booking b) => b.source == 'block';

/// Owner may cancel until the match starts (server raises `slot_started` afterwards).
bool canOwnerCancel(Booking b, DateTime now) {
  final live = b.status == BookingStatus.confirmed || b.status == BookingStatus.pendingPayment;
  return live && b.startsAt.isAfter(now);
}

/// Geldi / Gelmedi: started, real (non-block) bookings that were confirmed.
bool canMarkAttendance(Booking b, DateTime now) {
  if (isBlockBooking(b)) return false;
  final marked = b.status == BookingStatus.confirmed ||
      b.status == BookingStatus.completed ||
      b.status == BookingStatus.noShow;
  return marked && !b.startsAt.isAfter(now);
}

bool matchesOwnerFilter(Booking b, OwnerBookingFilter filter, DateTime now) {
  switch (filter) {
    case OwnerBookingFilter.all:
      return true;
    case OwnerBookingFilter.app:
      return isAppBooking(b);
    case OwnerBookingFilter.phone:
      return isManualBooking(b);
    case OwnerBookingFilter.blocked:
      return isBlockBooking(b);
    case OwnerBookingFilter.pending:
      return b.status == BookingStatus.pendingPayment;
  }
}

/// Mirrors the table constraint `deposit_kurus <= hourly_price_kurus * slot_minutes / 60`.
bool depositWithinPrice({required int depositKurus, required int hourlyPriceKurus, required int slotMinutes}) {
  return depositKurus <= hourlyPriceKurus * slotMinutes ~/ 60;
}

/// Whole-lira text -> kuruş, or null when it is not a positive/zero integer amount.
int? parseLiraToKurus(String input) {
  final cleaned = input.trim().replaceAll('.', '').replaceAll(' ', '');
  if (cleaned.isEmpty || !RegExp(r'^[0-9]{1,7}$').hasMatch(cleaned)) return null;
  return int.parse(cleaned) * 100;
}

enum OwnerCellKind {
  /// Free slot: tap to add a phone booking or close it.
  empty,

  /// First slot of a booking.
  booking,

  /// Later slot of a booking longer than one slot.
  continuation,

  /// This pitch has no slot starting at this time.
  none,
}

class OwnerCell {
  const OwnerCell({
    required this.kind,
    required this.pitch,
    required this.start,
    required this.end,
    this.booking,
    this.isPast = false,
  });

  final OwnerCellKind kind;
  final Pitch pitch;
  final DateTime start;
  final DateTime end;
  final Booking? booking;

  /// Empty slot that has already started: not tappable.
  final bool isPast;
}

class OwnerGridRow {
  const OwnerGridRow({required this.start, required this.cells});

  final DateTime start;

  /// One cell per pitch, in the order the pitches were given.
  final List<OwnerCell> cells;
}

/// Builds the "saha x saat" calendar of one business day.
/// Rows are the union of all pitches' slot starts; cancelled / expired bookings are ignored.
List<OwnerGridRow> buildOwnerGrid({
  required List<Pitch> pitches,
  required DayHours? hours,
  required DateTime date,
  required List<Booking> bookings,
  required DateTime now,
}) {
  final startsByPitch = <String, Set<int>>{};
  final allStarts = <int>{};
  for (final p in pitches) {
    final starts = ownerSlotStarts(date: date, hours: hours, slotMinutes: p.slotMinutes);
    startsByPitch[p.id] = starts.map((d) => d.millisecondsSinceEpoch).toSet();
    allStarts.addAll(startsByPitch[p.id]!);
  }
  final ordered = allStarts.toList()..sort();
  final live = bookings.where((b) => isLiveOwnerBooking(b, now)).toList();

  final rows = <OwnerGridRow>[];
  for (final ms in ordered) {
    final start = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final cells = <OwnerCell>[];
    for (final p in pitches) {
      final end = start.add(Duration(minutes: p.slotMinutes));
      Booking? covering;
      for (final b in live) {
        if (b.pitchId == p.id && !b.startsAt.isAfter(start) && b.endsAt.isAfter(start)) {
          covering = b;
          break;
        }
      }
      if (covering != null) {
        final first = covering.startsAt.isAtSameMomentAs(start);
        cells.add(OwnerCell(
          kind: first ? OwnerCellKind.booking : OwnerCellKind.continuation,
          pitch: p,
          start: start,
          end: end,
          booking: covering,
        ));
      } else if (startsByPitch[p.id]!.contains(ms)) {
        cells.add(OwnerCell(
          kind: OwnerCellKind.empty,
          pitch: p,
          start: start,
          end: end,
          isPast: !start.isAfter(now),
        ));
      } else {
        cells.add(OwnerCell(kind: OwnerCellKind.none, pitch: p, start: start, end: end));
      }
    }
    rows.add(OwnerGridRow(start: start, cells: cells));
  }
  return rows;
}
