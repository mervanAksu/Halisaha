import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/features/venues/domain/slot.dart';
import 'package:halisaha/features/venues/domain/slot_groups.dart';

/// Slot starting at Istanbul wall-clock [hour]:[minute] on 2026-11-25 (UTC+3).
Slot slotAt(int hour, {int minute = 0, SlotState state = SlotState.available}) {
  final start = DateTime.utc(2026, 11, 25, hour, minute).subtract(const Duration(hours: 3));
  return Slot(
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    state: state,
    priceKurus: 400000,
    depositKurus: 75000,
  );
}

void main() {
  group('slotPeriodOf', () {
    test('Akşam is 17:00-23:59', () {
      expect(slotPeriodOf(slotAt(17).startsAt), SlotPeriod.evening);
      expect(slotPeriodOf(slotAt(23, minute: 59).startsAt), SlotPeriod.evening);
    });

    test('Öğleden sonra is 12:00-16:59', () {
      expect(slotPeriodOf(slotAt(12).startsAt), SlotPeriod.afternoon);
      expect(slotPeriodOf(slotAt(16, minute: 59).startsAt), SlotPeriod.afternoon);
    });

    test('everything else is Sabah / Gece', () {
      expect(slotPeriodOf(slotAt(0).startsAt), SlotPeriod.night);
      expect(slotPeriodOf(slotAt(5).startsAt), SlotPeriod.night);
      expect(slotPeriodOf(slotAt(9).startsAt), SlotPeriod.night);
      expect(slotPeriodOf(slotAt(11, minute: 59).startsAt), SlotPeriod.night);
    });
  });

  group('groupSlots', () {
    test('orders groups Akşam, Öğleden sonra, Sabah/Gece', () {
      final groups = groupSlots([slotAt(9), slotAt(13), slotAt(20), slotAt(18), slotAt(14)]);
      expect(groups.map((g) => g.period).toList(), [SlotPeriod.evening, SlotPeriod.afternoon, SlotPeriod.night]);
      expect(groups[0].slots.length, 2);
      expect(groups[1].slots.length, 2);
      expect(groups[2].slots.length, 1);
    });

    test('is chronological inside a group, whatever the input order', () {
      final groups = groupSlots([slotAt(21), slotAt(17), slotAt(19)]);
      final starts = groups.single.slots.map((s) => s.startsAt).toList();
      final sorted = List<DateTime>.of(starts)..sort();
      expect(starts, sorted);
    });

    test('hides past slots but keeps booked ones, and drops empty groups', () {
      final groups = groupSlots([
        slotAt(13, state: SlotState.past),
        slotAt(14, state: SlotState.past),
        slotAt(18, state: SlotState.booked),
        slotAt(19),
      ]);
      expect(groups.length, 1);
      expect(groups.single.period, SlotPeriod.evening);
      expect(groups.single.slots.map((s) => s.state).toList(), [SlotState.booked, SlotState.available]);
    });

    test('all-past or empty input gives no groups', () {
      expect(groupSlots(const []), isEmpty);
      expect(groupSlots([slotAt(20, state: SlotState.past)]), isEmpty);
    });

    test('overnight venue: after-midnight slots land in Sabah / Gece after the day ones', () {
      final slots = [for (var h = 12; h < 24; h++) slotAt(h), for (var h = 0; h < 6; h++) slotAt(h + 24)];
      final groups = groupSlots(slots);
      expect(groups.map((g) => g.period).toList(), [SlotPeriod.evening, SlotPeriod.afternoon, SlotPeriod.night]);
      expect(groups[0].slots.length, 7); // 17..23
      expect(groups[1].slots.length, 5); // 12..16
      expect(groups[2].slots.length, 6); // 00..05
    });
  });

  group('slotGridColumns', () {
    test('3 columns up to 1.3x text scale, 2 above', () {
      expect(slotGridColumns(1.0), 3);
      expect(slotGridColumns(1.3), 3);
      expect(slotGridColumns(1.31), 2);
      expect(slotGridColumns(2.0), 2);
    });
  });

  test('hasAvailableSlot ignores booked and past slots', () {
    expect(hasAvailableSlot([slotAt(18, state: SlotState.booked), slotAt(19, state: SlotState.past)]), isFalse);
    expect(hasAvailableSlot([slotAt(18, state: SlotState.booked), slotAt(19)]), isTrue);
  });
}
