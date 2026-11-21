import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/utils/formatters.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/owner/domain/owner_logic.dart';
import 'package:halisaha/features/owner/domain/owner_models.dart';
import 'package:halisaha/features/venues/domain/pitch.dart';

Pitch pitch(String id, {int slotMinutes = 60, int price = 400000, int deposit = 75000}) => Pitch(
      id: id,
      name: 'Saha $id',
      format: '7v7',
      isIndoor: true,
      hourlyPriceKurus: price,
      depositKurus: deposit,
      slotMinutes: slotMinutes,
    );

/// Istanbul wall clock 2026-11-25 [hour]:00 (+[dayOffset] days) as a UTC instant.
DateTime ist(int hour, {int dayOffset = 0}) =>
    DateTime.utc(2026, 11, 25 + dayOffset, hour).subtract(const Duration(hours: 3));

Booking booking(
  String id,
  String pitchId,
  DateTime start, {
  int hours = 1,
  String source = 'app',
  BookingStatus status = BookingStatus.confirmed,
  DateTime? holdExpiresAt,
  String? name,
}) {
  return Booking(
    id: id,
    pitchId: pitchId,
    venueId: 'v1',
    source: source,
    status: status,
    startsAt: start,
    endsAt: start.add(Duration(hours: hours)),
    priceKurus: 400000,
    depositKurus: source == 'app' ? 75000 : 0,
    commissionKurus: 0,
    holdExpiresAt: holdExpiresAt,
    customerName: name,
  );
}

void main() {
  group('businessDayToday (before 06:00 Istanbul it is still yesterday)', () {
    // Istanbul = UTC+3.
    test('02:59 Istanbul belongs to the previous day', () {
      expect(businessDayToday(DateTime.utc(2026, 11, 20, 23, 59)), DateTime.utc(2026, 11, 20)); // 02:59 on the 21st
    });

    test('05:59 is still yesterday, 06:00 is the new day', () {
      expect(businessDayToday(DateTime.utc(2026, 11, 21, 2, 59)), DateTime.utc(2026, 11, 20)); // 05:59
      expect(businessDayToday(DateTime.utc(2026, 11, 21, 3, 0)), DateTime.utc(2026, 11, 21)); // 06:00
    });

    test('midnight Istanbul is yesterday, noon and 23:59 are today', () {
      expect(businessDayToday(DateTime.utc(2026, 11, 20, 21, 0)), DateTime.utc(2026, 11, 20)); // 00:00 on the 21st
      expect(businessDayToday(DateTime.utc(2026, 11, 21, 9, 0)), DateTime.utc(2026, 11, 21)); // 12:00
      expect(businessDayToday(DateTime.utc(2026, 11, 21, 20, 59)), DateTime.utc(2026, 11, 21)); // 23:59
    });

    test('rolls over month and year boundaries', () {
      expect(businessDayToday(DateTime.utc(2026, 12, 31, 22, 30)), DateTime.utc(2026, 12, 31)); // 01:30 on Jan 1
      expect(businessDayToday(DateTime.utc(2026, 12, 31, 21, 30)), DateTime.utc(2026, 12, 31)); // 00:30 on Jan 1
      expect(businessDayToday(DateTime.utc(2027, 1, 1, 3, 0)), DateTime.utc(2027, 1, 1)); // 06:00
    });

    test('does not depend on the device time zone flag of the input', () {
      final local = DateTime.utc(2026, 11, 21, 2, 59).toLocal();
      expect(businessDayToday(local), DateTime.utc(2026, 11, 20));
    });
  });

  test('ownerDayWindow covers 00:00 of the day until 06:00 of the next day (Istanbul)', () {
    final w = ownerDayWindow(DateTime.utc(2026, 11, 25));
    expect(w.fromUtc, DateTime.utc(2026, 11, 24, 21));
    expect(w.toUtc, DateTime.utc(2026, 11, 26, 3));
  });

  group('ownerSlotStarts', () {
    final date = DateTime.utc(2026, 11, 25);

    test('regular day 09:00-23:00 has 14 hourly slots', () {
      final starts = ownerSlotStarts(
        date: date,
        hours: const DayHours(isoWeekday: 3, closed: false, openMinutes: 540, closeMinutes: 1380),
        slotMinutes: 60,
      );
      expect(starts.length, 14);
      expect(formatIstanbulTime(starts.first), '09:00');
      expect(formatIstanbulTime(starts.last), '22:00');
    });

    test('overnight day 12:00-06:00 runs into the next calendar day', () {
      final starts = ownerSlotStarts(
        date: date,
        hours: const DayHours(isoWeekday: 3, closed: false, openMinutes: 720, closeMinutes: 360),
        slotMinutes: 60,
      );
      expect(starts.length, 18);
      expect(formatIstanbulTime(starts.last), '05:00');
      expect(toIstanbul(starts.last).day, 26);
    });

    test('closing at 00:00 means midnight', () {
      final starts = ownerSlotStarts(
        date: date,
        hours: const DayHours(isoWeekday: 3, closed: false, openMinutes: 600, closeMinutes: 0),
        slotMinutes: 60,
      );
      expect(starts.length, 14);
      expect(formatIstanbulTime(starts.last), '23:00');
    });

    test('closed or missing hours and 90-minute slots', () {
      expect(ownerSlotStarts(date: date, hours: const DayHours.closed(3), slotMinutes: 60), isEmpty);
      expect(ownerSlotStarts(date: date, hours: null, slotMinutes: 60), isEmpty);
      final starts = ownerSlotStarts(
        date: date,
        hours: const DayHours(isoWeekday: 3, closed: false, openMinutes: 600, closeMinutes: 960),
        slotMinutes: 90,
      );
      expect(starts.length, 4); // 10:00, 11:30, 13:00, 14:30
      expect(formatIstanbulTime(starts.last), '14:30');
    });
  });

  group('DayHours', () {
    test('overnight flag: close <= open, but closing at 00:00 is not "past midnight"', () {
      expect(const DayHours(isoWeekday: 1, closed: false, openMinutes: 720, closeMinutes: 360).overnight, isTrue);
      expect(const DayHours(isoWeekday: 1, closed: false, openMinutes: 540, closeMinutes: 1380).overnight, isFalse);
      expect(const DayHours(isoWeekday: 1, closed: false, openMinutes: 600, closeMinutes: 0).overnight, isFalse);
      expect(const DayHours.closed(1).overnight, isFalse);
    });

    test('formats and parses minutes', () {
      expect(DayHours.hhmm(0), '00:00');
      expect(DayHours.hhmm(1380), '23:00');
      expect(DayHours.parseMinutes('09:30:00'), 570);
      const d = DayHours(isoWeekday: 1, closed: false, openMinutes: 570, closeMinutes: 60);
      expect(d.openSql, '09:30:00');
      expect(d.closeSql, '01:00:00');
    });
  });

  group('buildOwnerGrid', () {
    final date = DateTime.utc(2026, 11, 25);
    const hours = DayHours(isoWeekday: 3, closed: false, openMinutes: 18 * 60, closeMinutes: 23 * 60);
    final p1 = pitch('1');
    final p2 = pitch('2');
    final now = ist(10);

    test('one row per slot, one cell per pitch; free slots are tappable', () {
      final rows = buildOwnerGrid(pitches: [p1, p2], hours: hours, date: date, bookings: const [], now: now);
      expect(rows.length, 5);
      expect(rows.every((r) => r.cells.length == 2), isTrue);
      expect(rows.expand((r) => r.cells).every((c) => c.kind == OwnerCellKind.empty && !c.isPast), isTrue);
    });

    test('places bookings, marks continuation cells of longer bookings', () {
      final rows = buildOwnerGrid(
        pitches: [p1, p2],
        hours: hours,
        date: date,
        bookings: [
          booking('a', '1', ist(19)),
          booking('m', '2', ist(20), hours: 2, source: 'manual', name: 'Ali'),
        ],
        now: now,
      );
      OwnerCell cell(int hour, int pitchIndex) =>
          rows.firstWhere((r) => formatIstanbulTime(r.start) == '$hour:00').cells[pitchIndex];
      expect(cell(19, 0).kind, OwnerCellKind.booking);
      expect(cell(19, 0).booking!.id, 'a');
      expect(cell(19, 1).kind, OwnerCellKind.empty);
      expect(cell(20, 1).kind, OwnerCellKind.booking);
      expect(cell(21, 1).kind, OwnerCellKind.continuation);
      expect(cell(21, 1).booking!.id, 'm');
      expect(cell(22, 1).kind, OwnerCellKind.empty);
    });

    test('ignores cancelled bookings and expired holds, keeps live holds', () {
      final rows = buildOwnerGrid(
        pitches: [p1],
        hours: hours,
        date: date,
        bookings: [
          booking('c', '1', ist(18), status: BookingStatus.cancelled),
          booking('e', '1', ist(19), status: BookingStatus.pendingPayment, holdExpiresAt: now.subtract(const Duration(minutes: 1))),
          booking('p', '1', ist(20), status: BookingStatus.pendingPayment, holdExpiresAt: now.add(const Duration(minutes: 5))),
        ],
        now: now,
      );
      expect(rows[0].cells.single.kind, OwnerCellKind.empty);
      expect(rows[1].cells.single.kind, OwnerCellKind.empty);
      expect(rows[2].cells.single.kind, OwnerCellKind.booking);
    });

    test('free slots that already started are flagged past', () {
      final rows = buildOwnerGrid(pitches: [p1], hours: hours, date: date, bookings: const [], now: ist(20, dayOffset: 0).add(const Duration(minutes: 5)));
      final flags = rows.map((r) => r.cells.single.isPast).toList();
      expect(flags, [true, true, true, false, false]); // 18, 19, 20 started; 21, 22 not
    });

    test('pitches with different slot lengths share rows; missing slots become "none"', () {
      final p90 = pitch('90', slotMinutes: 90);
      final rows = buildOwnerGrid(
        pitches: [p1, p90],
        hours: const DayHours(isoWeekday: 3, closed: false, openMinutes: 600, closeMinutes: 780),
        date: date,
        bookings: const [],
        now: now,
      );
      // p1: 10, 11, 12 ; p90: 10:00, 11:30.
      expect(rows.map((r) => formatIstanbulTime(r.start)).toList(), ['10:00', '11:00', '11:30', '12:00']);
      expect(rows[1].cells[1].kind, OwnerCellKind.none);
      expect(rows[2].cells[0].kind, OwnerCellKind.none);
    });

    test('closed day gives no rows', () {
      expect(buildOwnerGrid(pitches: [p1], hours: const DayHours.closed(3), date: date, bookings: const [], now: now), isEmpty);
    });
  });

  group('booking rules', () {
    final now = ist(20);

    test('owner can cancel until the match starts, never afterwards', () {
      expect(canOwnerCancel(booking('a', '1', ist(21)), now), isTrue);
      expect(canOwnerCancel(booking('a', '1', ist(20)), now), isFalse); // starts right now
      expect(canOwnerCancel(booking('a', '1', ist(19)), now), isFalse);
      expect(canOwnerCancel(booking('a', '1', ist(21), status: BookingStatus.cancelled), now), isFalse);
      expect(
        canOwnerCancel(booking('a', '1', ist(21), status: BookingStatus.pendingPayment, holdExpiresAt: now), now),
        isTrue,
      );
    });

    test('attendance only for started, non-block bookings', () {
      expect(canMarkAttendance(booking('a', '1', ist(19)), now), isTrue);
      expect(canMarkAttendance(booking('a', '1', ist(19), status: BookingStatus.completed), now), isTrue);
      expect(canMarkAttendance(booking('a', '1', ist(21)), now), isFalse);
      expect(canMarkAttendance(booking('b', '1', ist(19), source: 'block'), now), isFalse);
      expect(canMarkAttendance(booking('c', '1', ist(19), status: BookingStatus.cancelled), now), isFalse);
    });

    test('filters', () {
      final app = booking('a', '1', ist(21));
      final manual = booking('m', '1', ist(21), source: 'manual');
      final block = booking('b', '1', ist(21), source: 'block');
      final pending = booking('p', '1', ist(21), status: BookingStatus.pendingPayment, holdExpiresAt: ist(22));
      expect(matchesOwnerFilter(app, OwnerBookingFilter.app, now), isTrue);
      expect(matchesOwnerFilter(manual, OwnerBookingFilter.app, now), isFalse);
      expect(matchesOwnerFilter(manual, OwnerBookingFilter.phone, now), isTrue);
      expect(matchesOwnerFilter(block, OwnerBookingFilter.blocked, now), isTrue);
      expect(matchesOwnerFilter(pending, OwnerBookingFilter.pending, now), isTrue);
      expect(matchesOwnerFilter(app, OwnerBookingFilter.pending, now), isFalse);
      for (final b in [app, manual, block, pending]) {
        expect(matchesOwnerFilter(b, OwnerBookingFilter.all, now), isTrue);
      }
    });
  });

  group('pitch amounts', () {
    test('deposit must not exceed the slot price (same rule as the table constraint)', () {
      expect(depositWithinPrice(depositKurus: 400000, hourlyPriceKurus: 400000, slotMinutes: 60), isTrue);
      expect(depositWithinPrice(depositKurus: 400001, hourlyPriceKurus: 400000, slotMinutes: 60), isFalse);
      expect(depositWithinPrice(depositKurus: 600000, hourlyPriceKurus: 400000, slotMinutes: 90), isTrue);
      expect(depositWithinPrice(depositKurus: 600001, hourlyPriceKurus: 400000, slotMinutes: 90), isFalse);
      expect(depositWithinPrice(depositKurus: 0, hourlyPriceKurus: 400000, slotMinutes: 60), isTrue);
    });

    test('lira text becomes integer kuruş, never a double', () {
      expect(parseLiraToKurus('4000'), 400000);
      expect(parseLiraToKurus(' 750 '), 75000);
      expect(parseLiraToKurus('1.500'), 150000);
      expect(parseLiraToKurus('0'), 0);
      expect(parseLiraToKurus(''), isNull);
      expect(parseLiraToKurus('12,5'), isNull);
      expect(parseLiraToKurus('abc'), isNull);
      expect(parseLiraToKurus('-5'), isNull);
    });
  });
}
