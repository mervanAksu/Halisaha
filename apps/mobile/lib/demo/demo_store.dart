import '../core/errors/app_exception.dart';
import '../core/l10n/strings.dart';
import '../core/utils/formatters.dart';
import '../features/booking/domain/booking.dart';
import '../features/booking/domain/cancel_result.dart';
import '../features/booking/domain/payment_session.dart';
import '../features/profile/domain/profile.dart';
import '../features/venues/domain/pitch.dart';
import '../features/venues/domain/slot.dart';
import 'demo_availability.dart';
import 'demo_data.dart';

/// Hold length, same as the server (ADR-5).
const Duration demoHoldDuration = Duration(minutes: 10);

/// Thrown by operations that are switched off in the demo.
AppException demoDisabledException() => const AppException('demo_disabled', S.demoDisabled);

/// All mutable state of the demo, in memory. One instance lives in the root ProviderScope; the demo
/// repositories are thin views over it. Nothing is persisted: a page reload resets the demo.
class DemoStore {
  DemoStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seed();
  }

  static const String userId = 'demo-user';

  final DateTime Function() _clock;

  DateTime now() => _clock();

  late Profile profile = Profile(
    id: userId,
    fullName: 'Demo Oyuncu',
    phone: '+905550000000',
    kvkkAckAt: now().toUtc(),
  );

  final List<DemoVenue> venues = demoVenues;

  /// Demo switch "İşletmeci modunu dene": flips the demo user's role between customer and owner.
  void setOwnerMode(bool enabled) {
    profile = profile.copyWith(
      role: enabled ? 'owner' : 'customer',
      fullName: enabled ? 'Demo İşletmeci' : 'Demo Oyuncu',
    );
  }

  /// Insertion order = favourite order (newest last).
  final List<String> favoriteIds = <String>[];

  final List<Booking> _bookings = <Booking>[];

  /// Payment attempts per booking id, oldest first (`initiated`, `succeeded`, `failed`, `refund_required`).
  final Map<String, List<String>> _payments = <String, List<String>>{};

  int _nextId = 1;

  // --- Lookups ------------------------------------------------------------------

  DemoVenue? venueById(String id) {
    for (final v in venues) {
      if (v.id == id) return v;
    }
    return null;
  }

  DemoVenue? venueOfPitch(String pitchId) {
    for (final v in venues) {
      if (v.pitches.any((p) => p.id == pitchId)) return v;
    }
    return null;
  }

  Pitch? pitchById(String pitchId) {
    final venue = venueOfPitch(pitchId);
    if (venue == null) return null;
    return venue.pitches.firstWhere((p) => p.id == pitchId);
  }

  // --- Availability ---------------------------------------------------------------

  bool _isActive(Booking b) {
    final t = now();
    return b.status == BookingStatus.confirmed ||
        (b.status == BookingStatus.pendingPayment && b.holdExpiresAt != null && b.holdExpiresAt!.isAfter(t));
  }

  bool _takenByBooking(String pitchId, DateTime start, DateTime end) {
    return _bookings.any((b) => b.pitchId == pitchId && _isActive(b) && b.startsAt.isBefore(end) && b.endsAt.isAfter(start));
  }

  List<Slot> availability(String pitchId, String isoDate) {
    final venue = venueOfPitch(pitchId);
    final pitch = pitchById(pitchId);
    if (venue == null || pitch == null) throw AppException.fromCode('pitch_not_found');
    return generateDemoSlots(
      venue: venue,
      pitch: pitch,
      isoDate: isoDate,
      now: now(),
      isTaken: (s, e) => _takenByBooking(pitchId, s, e),
    );
  }

  // --- Favourites -----------------------------------------------------------------

  void setFavorite(String venueId, {required bool favorite}) {
    favoriteIds.remove(venueId);
    if (favorite) favoriteIds.add(venueId);
  }

  // --- Bookings -------------------------------------------------------------------

  Booking _build({
    required String id,
    required DemoVenue venue,
    required Pitch pitch,
    required BookingStatus status,
    required DateTime startsAt,
    DateTime? holdExpiresAt,
    DateTime? cancelledAt,
  }) {
    return Booking(
      id: id,
      pitchId: pitch.id,
      venueId: venue.id,
      userId: userId,
      source: 'app',
      status: status,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: pitch.slotMinutes)),
      priceKurus: pitch.hourlyPriceKurus * pitch.slotMinutes ~/ 60,
      depositKurus: pitch.depositKurus,
      commissionKurus: 0,
      holdExpiresAt: holdExpiresAt,
      cancelledAt: cancelledAt,
      pitchName: pitch.name,
      pitchFormat: pitch.format,
      venueName: venue.name,
      venueDistrict: venue.district,
      venueAddress: venue.address,
      venueLat: venue.lat,
      venueLng: venue.lng,
      cancellationWindowHours: venue.cancellationWindowHours,
    );
  }

  Booking _withStatus(Booking b, BookingStatus status, {DateTime? cancelledAt}) {
    return _build(
      id: b.id,
      venue: venueById(b.venueId)!,
      pitch: pitchById(b.pitchId)!,
      status: status,
      startsAt: b.startsAt,
      holdExpiresAt: b.holdExpiresAt,
      cancelledAt: cancelledAt ?? b.cancelledAt,
    );
  }

  int _indexOf(String bookingId) => _bookings.indexWhere((b) => b.id == bookingId);

  /// Like the server cron: an unpaid hold past its deadline becomes `expired`.
  void _expireStaleHolds() {
    final t = now();
    for (var i = 0; i < _bookings.length; i++) {
      final b = _bookings[i];
      if (b.status == BookingStatus.pendingPayment && b.holdExpiresAt != null && !b.holdExpiresAt!.isAfter(t)) {
        _bookings[i] = _withStatus(b, BookingStatus.expired);
      }
    }
  }

  /// Mirrors `create_booking_hold` (without the per-user quotas, which would only get in the way of a demo).
  Booking createHold(String pitchId, DateTime startsAt) {
    final venue = venueOfPitch(pitchId);
    final pitch = pitchById(pitchId);
    if (venue == null || pitch == null) throw AppException.fromCode('pitch_not_found');
    final t = now();
    final start = startsAt.toUtc();
    if (!start.isAfter(t.add(demoPastCutoff))) throw AppException.fromCode('slot_in_past');
    if (start.isAfter(t.add(const Duration(days: 30)))) throw AppException.fromCode('too_far_ahead');

    _expireStaleHolds();

    // The slot belongs to the business day of its Istanbul date or of the day before (overnight venues).
    final istanbulDay = istanbulToday(start);
    Slot? slot;
    for (final offset in const [0, -1]) {
      final day = DateTime.utc(istanbulDay.year, istanbulDay.month, istanbulDay.day + offset);
      for (final s in availability(pitchId, formatIsoDate(day))) {
        if (s.startsAt.isAtSameMomentAs(start)) slot = s;
      }
    }
    if (slot == null) throw AppException.fromCode('outside_opening_hours');
    if (slot.state != SlotState.available) throw AppException.fromCode('slot_taken');

    final zeroDeposit = pitch.depositKurus == 0;
    final booking = _build(
      id: 'demo-booking-${_nextId++}',
      venue: venue,
      pitch: pitch,
      status: zeroDeposit ? BookingStatus.confirmed : BookingStatus.pendingPayment,
      startsAt: start,
      holdExpiresAt: zeroDeposit ? null : t.add(demoHoldDuration),
    );
    _bookings.add(booking);
    return booking;
  }

  Booking fetchBooking(String bookingId) {
    _expireStaleHolds();
    final i = _indexOf(bookingId);
    if (i < 0) throw AppException.fromCode('booking_not_found');
    return _bookings[i];
  }

  List<Booking> myBookings() {
    _expireStaleHolds();
    return List<Booking>.of(_bookings)..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  String? latestPaymentStatus(String bookingId) {
    final list = _payments[bookingId];
    return list == null || list.isEmpty ? null : list.last;
  }

  /// Opens a payment attempt (`initiated`); the demo payment screen settles it.
  PaymentSession startPayment(String bookingId) {
    final booking = fetchBooking(bookingId);
    if (booking.status != BookingStatus.pendingPayment) throw AppException.fromCode('hold_expired');
    (_payments[bookingId] ??= <String>[]).add('initiated');
    return PaymentSession(
      iframeUrl: 'demo://payment/$bookingId',
      merchantOid: 'DEMO${bookingId.replaceAll('-', '')}',
      holdExpiresAt: booking.holdExpiresAt,
    );
  }

  /// Plays the PayTR callback: success confirms the booking, failure keeps the hold.
  /// A success that arrives after the hold expired is flagged for refund, like the real backend.
  void settlePayment(String bookingId, {required bool success}) {
    final i = _indexOf(bookingId);
    if (i < 0) throw AppException.fromCode('booking_not_found');
    _expireStaleHolds();
    final booking = _bookings[i];
    final list = _payments[bookingId] ??= <String>[];
    if (list.isNotEmpty) list.removeLast();
    if (!success) {
      list.add('failed');
    } else if (booking.status == BookingStatus.pendingPayment) {
      list.add('succeeded');
      _bookings[i] = _withStatus(booking, BookingStatus.confirmed);
    } else {
      list.add('refund_required');
    }
  }

  /// Mirrors `cancel_booking`: unpaid holds cancel for free; a confirmed booking refunds the deposit
  /// only when `starts_at - now >= cancellation window`.
  CancelResult cancel(String bookingId) {
    _expireStaleHolds();
    final i = _indexOf(bookingId);
    if (i < 0) throw AppException.fromCode('booking_not_found');
    final b = _bookings[i];
    final t = now();
    if (b.status == BookingStatus.pendingPayment) {
      _bookings[i] = _withStatus(b, BookingStatus.cancelled, cancelledAt: t);
      return const CancelResult(status: 'cancelled', refundEligible: false);
    }
    if (b.status != BookingStatus.confirmed || !b.startsAt.isAfter(t)) {
      throw AppException.fromCode('not_cancellable');
    }
    final window = Duration(hours: b.cancellationWindowHours ?? defaultCancellationWindowHours);
    final refund = b.startsAt.difference(t) >= window;
    _bookings[i] = _withStatus(b, BookingStatus.cancelled, cancelledAt: t);
    if (refund) (_payments[bookingId] ??= <String>[]).add('refund_required');
    return CancelResult(status: 'cancelled', refundEligible: refund);
  }

  // --- Seed -----------------------------------------------------------------------

  /// Istanbul wall-clock [hour] on the day [daysFromToday] away, as a UTC instant.
  DateTime _istanbulInstant(int daysFromToday, int hour) {
    final today = istanbulToday(now());
    return DateTime.utc(today.year, today.month, today.day + daysFromToday, hour).subtract(istanbulOffset);
  }

  void _seed() {
    favoriteIds.add('demo-venue-4');

    void add(DemoVenue venue, int pitchIndex, BookingStatus status, int day, int hour) {
      final pitch = venue.pitches[pitchIndex];
      _bookings.add(_build(
        id: 'demo-booking-seed-${_bookings.length + 1}',
        venue: venue,
        pitch: pitch,
        status: status,
        startsAt: _istanbulInstant(day, hour),
      ));
    }

    add(venueById('demo-venue-1')!, 0, BookingStatus.completed, -12, 21);
    add(venueById('demo-venue-4')!, 1, BookingStatus.completed, -5, 20);
    add(venueById(demoOvernightVenueId)!, 0, BookingStatus.confirmed, 3, 22);
  }
}
