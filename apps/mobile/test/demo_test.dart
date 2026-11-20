import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/errors/app_exception.dart';
import 'package:halisaha/core/utils/formatters.dart';
import 'package:halisaha/demo/demo_availability.dart';
import 'package:halisaha/demo/demo_data.dart';
import 'package:halisaha/demo/demo_repositories.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/booking/presentation/booking_providers.dart';
import 'package:halisaha/features/venues/domain/slot.dart';

void main() {
  // 2026-11-20 10:00 Istanbul (07:00 UTC).
  final now = DateTime.utc(2026, 11, 20, 7);
  final overnight = demoVenues.firstWhere((v) => v.id == demoOvernightVenueId);
  final regular = demoVenues.first;

  List<Slot> slotsFor(DemoVenue v, String date, DateTime clock) =>
      generateDemoSlots(venue: v, pitch: v.pitches.first, isoDate: date, now: clock);

  group('generateDemoSlots', () {
    test('is deterministic', () {
      final a = slotsFor(regular, '2026-11-25', now);
      final b = slotsFor(regular, '2026-11-25', now);
      expect(a.map((s) => '${s.startsAt}|${s.state}').toList(), b.map((s) => '${s.startsAt}|${s.state}').toList());
    });

    test('differs between days and produces a mix of available and booked', () {
      final states = <SlotState>{};
      final patterns = <String>{};
      for (var d = 21; d <= 30; d++) {
        final slots = slotsFor(regular, '2026-11-$d', now);
        patterns.add(slots.map((s) => s.state.name).join(','));
        states.addAll(slots.map((s) => s.state));
      }
      expect(states, containsAll([SlotState.available, SlotState.booked]));
      expect(patterns.length, greaterThan(1));
    });

    test('applies the 15-minute past rule like the server', () {
      final target = slotsFor(regular, '2026-11-25', now)[3].startsAt;
      SlotState stateAt(DateTime clock) =>
          slotsFor(regular, '2026-11-25', clock).firstWhere((s) => s.startsAt == target).state;
      expect(stateAt(target.subtract(const Duration(minutes: 14))), SlotState.past);
      expect(stateAt(target.subtract(const Duration(minutes: 15))), SlotState.past);
      expect(stateAt(target.subtract(const Duration(minutes: 16))), isNot(SlotState.past));
      expect(stateAt(target.add(const Duration(hours: 2))), SlotState.past);
    });

    test('regular venue stays inside opening hours; prices are int kurus', () {
      final slots = slotsFor(regular, '2026-11-25', now);
      expect(slots.length, 14); // 09:00-23:00
      expect(formatIstanbulTime(slots.first.startsAt), '09:00');
      expect(formatIstanbulTime(slots.last.endsAt), '23:00');
      expect(slots.first.priceKurus, regular.pitches.first.hourlyPriceKurus);
      expect(slots.first.depositKurus, regular.pitches.first.depositKurus);
    });

    test('overnight venue (12:00-06:00) produces slots after midnight', () {
      final slots = slotsFor(overnight, '2026-11-25', now);
      expect(slots.length, 18);
      expect(formatIstanbulTime(slots.first.startsAt), '12:00');
      expect(formatIstanbulTime(slots.last.startsAt), '05:00');
      expect(formatIstanbulTime(slots.last.endsAt), '06:00');
      final firstDay = toIstanbul(slots.first.startsAt).day;
      final afterMidnight = slots.where((s) => toIstanbul(s.startsAt).day != firstDay).toList();
      expect(afterMidnight.length, 6); // 00:00..05:00
      expect(toIstanbul(afterMidnight.first.startsAt).day, 26);
    });

    test('slots are contiguous and never overlap', () {
      final slots = slotsFor(overnight, '2026-11-25', now);
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].startsAt, slots[i - 1].endsAt);
      }
    });
  });

  group('demo booking flow', () {
    late DemoStore store;
    late DemoBookingRepository repo;

    DateTime? firstAvailable(String pitchId) {
      for (var d = 1; d <= 10; d++) {
        final day = istanbulToday(now).add(Duration(days: d));
        for (final s in store.availability(pitchId, formatIsoDate(day))) {
          if (s.isAvailable) return s.startsAt;
        }
      }
      return null;
    }

    setUp(() {
      store = DemoStore(clock: () => now);
      repo = DemoBookingRepository(store);
    });

    test('is seeded with 2 past and 1 upcoming match', () async {
      final all = await repo.fetchMyBookings();
      expect(all.where((b) => b.isUpcoming(now)).length, 1);
      expect(all.where((b) => !b.isUpcoming(now)).length, 2);
    });

    test('hold + successful payment -> confirmed and listed as upcoming', () async {
      final pitch = regular.pitches.first;
      final start = firstAvailable(pitch.id)!;
      final hold = await repo.createHold(pitchId: pitch.id, startsAt: start);
      expect(hold.status, BookingStatus.pendingPayment);
      expect(hold.depositKurus, pitch.depositKurus);

      await repo.startPayment(hold.id);
      expect(await repo.fetchLatestPaymentStatus(hold.id), 'initiated');
      store.settlePayment(hold.id, success: true);

      final booking = await repo.fetchBooking(hold.id);
      expect(booking.status, BookingStatus.confirmed);
      expect(decidePaymentOutcome(booking.status, await repo.fetchLatestPaymentStatus(hold.id)), PaymentOutcome.success);

      final mine = await repo.fetchMyBookings();
      final upcoming = mine.where((b) => b.isUpcoming(now)).toList();
      expect(upcoming.map((b) => b.id), contains(hold.id));
      expect(upcoming.length, 2);
    });

    test('failed payment keeps the hold; the slot becomes unavailable', () async {
      final pitch = regular.pitches.first;
      final start = firstAvailable(pitch.id)!;
      final hold = await repo.createHold(pitchId: pitch.id, startsAt: start);
      await repo.startPayment(hold.id);
      store.settlePayment(hold.id, success: false);

      final booking = await repo.fetchBooking(hold.id);
      expect(booking.status, BookingStatus.pendingPayment);
      expect(decidePaymentOutcome(booking.status, await repo.fetchLatestPaymentStatus(hold.id)), PaymentOutcome.failed);
      expect(
        () => repo.createHold(pitchId: pitch.id, startsAt: start),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'slot_taken')),
      );
    });

    test('cancel refunds only outside the cancellation window', () async {
      var current = now;
      final clockStore = DemoStore(clock: () => current);
      final clockRepo = DemoBookingRepository(clockStore);
      final pitch = regular.pitches.first; // 24 h window

      DateTime? pick() {
        for (var d = 2; d <= 10; d++) {
          final day = istanbulToday(now).add(Duration(days: d));
          for (final s in clockStore.availability(pitch.id, formatIsoDate(day))) {
            if (s.isAvailable) return s.startsAt;
          }
        }
        return null;
      }

      Future<String> book(DateTime start) async {
        final hold = await clockRepo.createHold(pitchId: pitch.id, startsAt: start);
        await clockRepo.startPayment(hold.id);
        clockStore.settlePayment(hold.id, success: true);
        return hold.id;
      }

      final start = pick()!;
      final far = await book(start);
      expect((await clockRepo.cancel(far)).refundEligible, isTrue); // days away
      expect((await clockRepo.fetchBooking(far)).status, BookingStatus.cancelled);
      expect(await clockRepo.fetchLatestPaymentStatus(far), 'refund_required');

      final near = await book(start); // slot is free again after the cancellation
      current = start.subtract(const Duration(hours: 2)); // inside the 24 h window
      expect((await clockRepo.cancel(near)).refundEligible, isFalse);

      // An already cancelled booking cannot be cancelled again.
      await expectLater(
        clockRepo.cancel(near),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'not_cancellable')),
      );
    });

    test('profile edit works; sign-out and delete are disabled', () async {
      final profiles = DemoProfileRepository(store);
      final updated = await profiles.updateName(userId: DemoStore.userId, fullName: 'Ayşe Yıldız');
      expect(updated.fullName, 'Ayşe Yıldız');
      expect(updated.needsOnboarding, isFalse);
      await expectLater(DemoAuthRepository().signOut(), throwsA(isA<Object>()));
      await expectLater(profiles.deleteAccount(), throwsA(isA<Object>()));
    });

    test('search folds Turkish characters and district filter works', () async {
      final venues = DemoVenuesRepository(store);
      expect((await venues.listVenues(search: 'atasehir')).map((v) => v.district), everyElement('Ataşehir'));
      final kadikoy = await venues.listVenues(district: 'Kadıköy');
      expect(kadikoy, isNotEmpty);
      expect(kadikoy.every((v) => v.district == 'Kadıköy'), isTrue);
    });
  });
}
