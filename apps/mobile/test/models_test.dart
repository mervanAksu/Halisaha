import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/venues/domain/slot.dart';
import 'package:halisaha/features/venues/domain/venue_summary.dart';

Map<String, dynamic> bookingJson({
  String status = 'confirmed',
  String startsAt = '2026-12-06T17:00:00+00:00',
  String endsAt = '2026-12-06T18:00:00+00:00',
  int deposit = 70000,
  String? holdExpiresAt,
  Object? venues = const {'name': 'Yıldız Halı Saha', 'district': 'Kadıköy', 'cancellation_window_hours': 24},
}) {
  return {
    'id': 'b1',
    'pitch_id': 'p1',
    'venue_id': 'v1',
    'user_id': 'u1',
    'source': 'app',
    'status': status,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'price_kurus': 350000,
    'deposit_kurus': deposit,
    'commission_kurus': 7000,
    'hold_expires_at': holdExpiresAt,
    'cancelled_at': null,
    'pitches': {'name': 'Saha 1', 'format': '7v7'},
    'venues': venues,
  };
}

void main() {
  group('Booking.fromJson', () {
    test('parses columns and joined pitch/venue', () {
      final b = Booking.fromJson(bookingJson());
      expect(b.id, 'b1');
      expect(b.status, BookingStatus.confirmed);
      expect(b.startsAt, DateTime.utc(2026, 12, 6, 17));
      expect(b.startsAt.isUtc, isTrue);
      expect(b.priceKurus, 350000);
      expect(b.depositKurus, 70000);
      expect(b.remainderKurus, 280000);
      expect(b.pitchName, 'Saha 1');
      expect(b.pitchFormat, '7v7');
      expect(b.venueName, 'Yıldız Halı Saha');
      expect(b.venueDistrict, 'Kadıköy');
      expect(b.cancellationWindowHours, 24);
      expect(b.holdExpiresAt, isNull);
    });

    test('tolerates missing joins (e.g. suspended venue)', () {
      final b = Booking.fromJson(bookingJson(venues: null));
      expect(b.venueName, isNull);
      expect(b.cancellationWindowHours, isNull);
    });

    test('parses every status wire value', () {
      for (final s in BookingStatus.values) {
        expect(BookingStatus.fromWire(s.wire), s);
      }
      expect(() => BookingStatus.fromWire('bogus'), throwsFormatException);
    });
  });

  group('Booking rules', () {
    final now = DateTime.utc(2026, 12, 5, 12);

    test('upcoming vs past', () {
      expect(Booking.fromJson(bookingJson()).isUpcoming(now), isTrue);
      expect(Booking.fromJson(bookingJson(status: 'cancelled')).isUpcoming(now), isFalse);
      expect(Booking.fromJson(bookingJson(status: 'completed')).isUpcoming(now), isFalse);
      expect(Booking.fromJson(bookingJson()).isUpcoming(DateTime.utc(2026, 12, 6, 19)), isFalse);
    });

    test('expired hold is shown as expired', () {
      final b = Booking.fromJson(bookingJson(status: 'pending_payment', holdExpiresAt: '2026-12-05T11:55:00+00:00'));
      expect(b.displayStatus(now), BookingStatus.expired);
      expect(b.isUpcoming(now), isFalse);
      final live = Booking.fromJson(bookingJson(status: 'pending_payment', holdExpiresAt: '2026-12-05T12:05:00+00:00'));
      expect(live.displayStatus(now), BookingStatus.pendingPayment);
      expect(live.isUpcoming(now), isTrue);
      expect(live.canCancel(now), isTrue);
    });

    test('refund preview mirrors cancel_booking', () {
      // 29 h before the match, window 24 h -> refundable.
      expect(Booking.fromJson(bookingJson()).refundPreview(now), RefundPreview.refundable);
      // exactly at the window -> refundable (>=).
      expect(Booking.fromJson(bookingJson()).refundPreview(DateTime.utc(2026, 12, 5, 17)), RefundPreview.refundable);
      // 10 h before -> forfeited.
      expect(Booking.fromJson(bookingJson()).refundPreview(DateTime.utc(2026, 12, 6, 7)), RefundPreview.forfeited);
      expect(Booking.fromJson(bookingJson(deposit: 0)).refundPreview(now), RefundPreview.noDeposit);
      expect(
        Booking.fromJson(bookingJson(status: 'pending_payment', holdExpiresAt: '2026-12-05T12:05:00+00:00'))
            .refundPreview(now),
        RefundPreview.notCharged,
      );
    });

    test('cannot cancel once the match started', () {
      expect(Booking.fromJson(bookingJson()).canCancel(DateTime.utc(2026, 12, 6, 17, 30)), isFalse);
    });
  });

  group('VenueSummary.fromJson', () {
    test('parses list_venues row', () {
      final v = VenueSummary.fromJson({
        'id': 'v1',
        'name': 'Yıldız Halı Saha',
        'district': 'Kadıköy',
        'address': 'Moda Cd. 1',
        'cover_photo_path': 'v1/cover.jpg',
        'min_hourly_price_kurus': 350000,
        'open_time': '18:00:00',
        'close_time': '02:00:00',
        'distance_km': 2.5,
        'is_favorite': true,
      });
      expect(v.minHourlyPriceKurus, 350000);
      expect(v.openTime, '18:00');
      expect(v.closeTime, '02:00');
      expect(v.isOpenToday, isTrue);
      expect(v.distanceKm, 2.5);
      expect(v.isFavorite, isTrue);
    });

    test('handles nulls (closed today, no location, no price)', () {
      final v = VenueSummary.fromJson({
        'id': 'v2',
        'name': 'Kapalı Saha',
        'district': 'Beşiktaş',
        'address': '',
        'cover_photo_path': null,
        'min_hourly_price_kurus': null,
        'open_time': null,
        'close_time': null,
        'distance_km': null,
        'is_favorite': false,
      });
      expect(v.isOpenToday, isFalse);
      expect(v.minHourlyPriceKurus, isNull);
      expect(v.distanceKm, isNull);
      expect(v.coverPhotoPath, isNull);
    });
  });

  group('Slot.fromJson', () {
    test('parses get_availability row', () {
      final s = Slot.fromJson({
        'starts_at': '2026-12-06T17:00:00+00:00',
        'ends_at': '2026-12-06T18:00:00+00:00',
        'state': 'available',
        'price_kurus': 350000,
        'deposit_kurus': 70000,
      });
      expect(s.startsAt, DateTime.utc(2026, 12, 6, 17));
      expect(s.endsAt, DateTime.utc(2026, 12, 6, 18));
      expect(s.state, SlotState.available);
      expect(s.isAvailable, isTrue);
      expect(s.priceKurus, 350000);
      expect(s.depositKurus, 70000);
    });

    test('maps states; unknown is treated as booked', () {
      expect(SlotState.fromWire('booked'), SlotState.booked);
      expect(SlotState.fromWire('past'), SlotState.past);
      expect(SlotState.fromWire('weird'), SlotState.booked);
    });
  });
}
