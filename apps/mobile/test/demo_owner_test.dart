import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/errors/app_exception.dart';
import 'package:halisaha/core/utils/formatters.dart';
import 'package:halisaha/demo/demo_data.dart';
import 'package:halisaha/demo/demo_owner_repository.dart';
import 'package:halisaha/demo/demo_repositories.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/owner/domain/owner_logic.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';

void main() {
  // 2026-11-20 19:00 Istanbul (16:00 UTC): a Friday evening.
  final now = DateTime.utc(2026, 11, 20, 16);
  late DemoStore store;
  late DemoOwnerRepository repo;

  /// Istanbul wall clock hour of business day 2026-11-20 (+day) as UTC.
  DateTime at(int hour, {int day = 0}) => DateTime.utc(2026, 11, 20 + day, hour).subtract(istanbulOffset);

  Future<List<Booking>> todayOf(String venueId) {
    final window = ownerDayWindow(businessDayToday(now));
    return repo.fetchBookings(venueId: venueId, fromUtc: window.fromUtc, toUtc: window.toUtc);
  }

  setUp(() {
    store = DemoStore(clock: () => now);
    repo = DemoOwnerRepository(store);
  });

  Future<AppException> failure(Future<Object?> Function() action) async {
    try {
      await action();
    } on AppException catch (e) {
      return e;
    }
    fail('expected an AppException');
  }

  group('demo owner mode switch', () {
    test('the demo user starts as a customer and the switch makes them an owner', () {
      expect(store.profile.isOwner, isFalse);
      store.setOwnerMode(true);
      expect(store.profile.role, 'owner');
      expect(store.profile.isOwner, isTrue);
      store.setOwnerMode(false);
      expect(store.profile.isOwner, isFalse);
    });

    test('switching keeps the rest of the profile', () {
      final before = store.profile;
      store.setOwnerMode(true);
      expect(store.profile.fullName, before.fullName);
      expect(store.profile.phone, before.phone);
      expect(store.profile.kvkkAckAt, before.kvkkAckAt);
    });
  });

  group('venues, pitches, hours', () {
    test('owns two demo venues, one of them overnight', () async {
      final venues = await repo.fetchMyVenues();
      expect(venues.map((v) => v.id).toList(), demoOwnedVenueIds);
      expect(venues.length, 2);
      final hours = await repo.fetchHours(demoOvernightVenueId);
      expect(hours.length, 7);
      expect(hours.every((d) => !d.closed && d.overnight), isTrue);
    });

    test('pitches are listed per venue', () async {
      expect((await repo.fetchPitches('demo-venue-1')).length, 3);
      expect((await repo.fetchPitches(demoOvernightVenueId)).length, 2);
    });

    test('saved hours are returned next time, including a closed day', () async {
      final days = await repo.fetchHours('demo-venue-1');
      final edited = [for (final d in days) d.isoWeekday == 2 ? d.copyWith(closed: true) : d];
      await repo.saveHours('demo-venue-1', edited);
      final again = await repo.fetchHours('demo-venue-1');
      expect(again.firstWhere((d) => d.isoWeekday == 2).closed, isTrue);
      expect(again.firstWhere((d) => d.isoWeekday == 3).closed, isFalse);
    });
  });

  group('seeded bookings', () {
    test('today has a realistic mix of app, manual, block and pending bookings', () async {
      final today = await todayOf('demo-venue-1');
      expect(today.map((b) => b.source).toSet(), containsAll(['app', 'manual', 'block']));
      expect(today.any((b) => b.status == BookingStatus.pendingPayment), isTrue);
      final pending = today.firstWhere((b) => b.status == BookingStatus.pendingPayment);
      expect(pending.holdExpiresAt!.isAfter(now), isTrue);
    });

    test('app bookings carry a user id with a contact, manual ones carry name and phone', () async {
      final today = await todayOf('demo-venue-1');
      final app = today.firstWhere((b) => b.source == 'app' && b.userId != null);
      final contacts = await repo.fetchContacts([app.userId!]);
      expect(contacts.single.fullName, isNotEmpty);
      expect(contacts.single.phone, startsWith('+90'));
      final manual = today.firstWhere((b) => b.source == 'manual');
      expect(manual.customerName, isNotEmpty);
      expect(manual.customerPhone, isNotEmpty);
    });

    test('the overnight venue has a booking after midnight inside the same business day', () async {
      final today = await todayOf(demoOvernightVenueId);
      expect(today.any((b) => toIstanbul(b.startsAt).hour < 6), isTrue);
    });

    test('bookings of a venue never overlap on a pitch', () async {
      for (final venueId in demoOwnedVenueIds) {
        final all = await repo.fetchBookings(venueId: venueId, fromUtc: at(0, day: -5), toUtc: at(0, day: 10));
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            if (all[i].pitchId != all[j].pitchId) continue;
            final overlap = all[i].startsAt.isBefore(all[j].endsAt) && all[j].startsAt.isBefore(all[i].endsAt);
            expect(overlap, isFalse, reason: '${all[i].id} vs ${all[j].id}');
          }
        }
      }
    });
  });

  group('manual bookings and closed slots', () {
    test('a phone booking is created as confirmed manual and priced from the pitch', () async {
      final created = await repo.createManualBooking(
        pitchId: 'demo-pitch-1c',
        startsAt: at(20),
        endsAt: at(21),
        source: 'manual',
        customerName: 'Test Kişi',
        customerPhone: '+905550000999',
      );
      expect(created.source, 'manual');
      expect(created.status, BookingStatus.confirmed);
      expect(created.priceKurus, 300000);
      expect(created.depositKurus, 0);
      expect(created.userId, isNull);
      expect((await todayOf('demo-venue-1')).any((b) => b.id == created.id), isTrue);
    });

    test('closing a slot creates a free-of-charge block', () async {
      final created = await repo.createManualBooking(
        pitchId: 'demo-pitch-1c',
        startsAt: at(15),
        endsAt: at(16),
        source: 'block',
      );
      expect(created.source, 'block');
      expect(created.priceKurus, 0);
    });

    test('double booking is refused with slot_taken', () async {
      final e = await failure(() => repo.createManualBooking(
            pitchId: 'demo-pitch-1a',
            startsAt: at(20),
            endsAt: at(21),
            source: 'manual',
            customerName: 'X',
          ));
      expect(e.code, 'slot_taken');
    });

    test('a slot freed by cancelling can be booked again', () async {
      final today = await todayOf('demo-venue-1');
      final victim = today.firstWhere((b) => b.source == 'app' && b.startsAt.isAfter(now));
      await repo.cancelBooking(victim.id);
      final created = await repo.createManualBooking(
        pitchId: victim.pitchId,
        startsAt: victim.startsAt,
        endsAt: victim.endsAt,
        source: 'manual',
        customerName: 'Yeni',
      );
      expect(created.status, BookingStatus.confirmed);
    });

    test('invalid source and invalid range are refused', () async {
      expect(
        (await failure(() => repo.createManualBooking(pitchId: 'demo-pitch-1c', startsAt: at(15), endsAt: at(16), source: 'app'))).code,
        'invalid_source',
      );
      expect(
        (await failure(() => repo.createManualBooking(pitchId: 'demo-pitch-1c', startsAt: at(16), endsAt: at(15), source: 'block'))).code,
        'invalid_range',
      );
    });

    test('unknown pitch is forbidden', () async {
      final e = await failure(() => repo.createManualBooking(pitchId: 'nope', startsAt: at(15), endsAt: at(16), source: 'block'));
      expect(e.code, 'forbidden');
    });
  });

  group('cancel and attendance', () {
    test('cancelling a future booking works and frees it', () async {
      final today = await todayOf('demo-venue-1');
      final future = today.firstWhere((b) => b.source == 'manual' && b.startsAt.isAfter(now));
      final cancelled = await repo.cancelBooking(future.id);
      expect(cancelled.status, BookingStatus.cancelled);
      final after = await todayOf('demo-venue-1');
      expect(after.firstWhere((b) => b.id == future.id).status, BookingStatus.cancelled);
    });

    test('a booking that already started raises slot_started', () async {
      final today = await todayOf('demo-venue-1');
      final started = today.firstWhere((b) => !b.startsAt.isAfter(now) && b.status == BookingStatus.confirmed);
      final e = await failure(() => repo.cancelBooking(started.id));
      expect(e.code, 'slot_started');
    });

    test('cancelling twice is not_cancellable', () async {
      final today = await todayOf('demo-venue-1');
      final future = today.firstWhere((b) => b.source == 'manual' && b.startsAt.isAfter(now));
      await repo.cancelBooking(future.id);
      expect((await failure(() => repo.cancelBooking(future.id))).code, 'not_cancellable');
    });

    test('an unpaid hold can be cancelled by the owner', () async {
      final today = await todayOf('demo-venue-1');
      final hold = today.firstWhere((b) => b.status == BookingStatus.pendingPayment);
      expect((await repo.cancelBooking(hold.id)).status, BookingStatus.cancelled);
    });

    test('Geldi / Gelmedi works only after the start', () async {
      final yesterday = await repo.fetchBookings(venueId: 'demo-venue-1', fromUtc: at(0, day: -1), toUtc: at(0));
      final past = yesterday.firstWhere((b) => b.status == BookingStatus.confirmed);
      expect((await repo.markAttendance(past.id, attended: true)).status, BookingStatus.completed);
      expect((await repo.markAttendance(past.id, attended: false)).status, BookingStatus.noShow);

      final today = await todayOf('demo-venue-1');
      final future = today.firstWhere((b) => b.source == 'manual' && b.startsAt.isAfter(now));
      expect((await failure(() => repo.markAttendance(future.id, attended: true))).code, 'invalid_status');
    });

    test('closed slots cannot be marked', () async {
      final today = await todayOf('demo-venue-1');
      final block = today.firstWhere((b) => b.source == 'block');
      expect((await failure(() => repo.markAttendance(block.id, attended: true))).code, 'invalid_status');
    });

    test('unknown booking is forbidden', () async {
      expect((await failure(() => repo.cancelBooking('nope'))).code, 'forbidden');
    });
  });

  group('pitches', () {
    test('price, deposit and active flag can be changed', () async {
      final updated = await repo.updatePitch(
        pitchId: 'demo-pitch-1a',
        hourlyPriceKurus: 450000,
        depositKurus: 80000,
        isActive: false,
      );
      expect(updated.hourlyPriceKurus, 450000);
      expect(updated.depositKurus, 80000);
      expect(updated.isActive, isFalse);
      final listed = (await repo.fetchPitches('demo-venue-1')).firstWhere((p) => p.id == 'demo-pitch-1a');
      expect(listed.hourlyPriceKurus, 450000);
      expect(listed.isActive, isFalse);
      expect(listed.name, 'Saha 1');
    });

    test('deposit above the slot price is refused', () async {
      final e = await failure(() => repo.updatePitch(
            pitchId: 'demo-pitch-1a',
            hourlyPriceKurus: 400000,
            depositKurus: 400001,
            isActive: true,
          ));
      expect(e.code, 'invalid_range');
    });
  });

  group('nearestAvailableDayProvider', () {
    test('finds the first later day with a free slot, using the existing availability data', () async {
      final container = ProviderContainer(
        overrides: [venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(store))],
      );
      addTearDown(container.dispose);
      const key = (pitchId: 'demo-pitch-1a', fromIsoDate: '2026-11-22', maxDays: 13);
      final sub = container.listen(nearestAvailableDayProvider(key), (_, __) {});
      addTearDown(sub.close);
      final day = await container.read(nearestAvailableDayProvider(key).future);
      expect(day, isNotNull);
      final from = DateTime.utc(2026, 11, 22);
      expect(day!.isAfter(from), isTrue);
      expect(day.difference(from).inDays, lessThanOrEqualTo(13));
      expect(store.availability('demo-pitch-1a', formatIsoDate(day)).any((s) => s.isAvailable), isTrue);
    });

    test('searches no further than maxDays', () async {
      final container = ProviderContainer(
        overrides: [venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(store))],
      );
      addTearDown(container.dispose);
      const key = (pitchId: 'demo-pitch-1a', fromIsoDate: '2026-11-22', maxDays: 0);
      final sub = container.listen(nearestAvailableDayProvider(key), (_, __) {});
      addTearDown(sub.close);
      expect(await container.read(nearestAvailableDayProvider(key).future), isNull);
    });
  });
}
