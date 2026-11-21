import '../core/errors/app_exception.dart';
import '../core/l10n/strings.dart';
import '../core/utils/formatters.dart';
import '../features/booking/domain/booking.dart';
import '../features/owner/data/owner_repository.dart';
import '../features/owner/domain/owner_logic.dart';
import '../features/owner/domain/owner_models.dart';
import '../features/venues/domain/pitch.dart';
import 'demo_data.dart';
import 'demo_store.dart';

/// Ids of the demo venues the demo "işletmeci" owns (Mavi Çim: 09-23, Gece Kuşu: 12-06).
const List<String> demoOwnedVenueIds = <String>['demo-venue-1', demoOvernightVenueId];

/// In-memory [OwnerRepository] for the web preview. State lives in this object only; a reload
/// resets it. Mirrors the server rules the UI depends on: `slot_taken`, `invalid_range`,
/// `not_cancellable`, `slot_started`, `invalid_status`.
class DemoOwnerRepository implements OwnerRepository {
  DemoOwnerRepository(this._store) {
    _seed();
  }

  final DemoStore _store;

  final Map<String, List<Pitch>> _pitches = <String, List<Pitch>>{};
  final Map<String, List<DayHours>> _hours = <String, List<DayHours>>{};
  final List<Booking> _bookings = <Booking>[];
  final Map<String, OwnerContact> _contacts = <String, OwnerContact>{};
  int _nextId = 1;

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 150));

  List<DemoVenue> get _venues => [for (final id in demoOwnedVenueIds) _store.venueById(id)!];

  // --- Reads ---------------------------------------------------------------------------------

  @override
  Future<List<OwnerVenue>> fetchMyVenues() async {
    await _latency();
    return [for (final v in _venues) OwnerVenue(id: v.id, name: v.name, district: v.district)];
  }

  @override
  Future<List<Pitch>> fetchPitches(String venueId) async {
    await _latency();
    return List<Pitch>.of(_pitches[venueId] ?? const <Pitch>[]);
  }

  @override
  Future<List<DayHours>> fetchHours(String venueId) async {
    await _latency();
    return List<DayHours>.of(_hours[venueId] ?? [for (var d = 1; d <= 7; d++) DayHours.closed(d)]);
  }

  @override
  Future<void> saveHours(String venueId, List<DayHours> days) async {
    await _latency();
    _hours[venueId] = List<DayHours>.of(days);
  }

  @override
  Future<List<Booking>> fetchBookings({
    required String venueId,
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    await _latency();
    _expireHolds();
    final list = _bookings
        .where((b) => b.venueId == venueId && !b.startsAt.isBefore(fromUtc) && b.startsAt.isBefore(toUtc))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  @override
  Future<List<OwnerContact>> fetchContacts(List<String> userIds) async {
    await _latency();
    return [for (final id in userIds) if (_contacts[id] != null) _contacts[id]!];
  }

  // --- Writes --------------------------------------------------------------------------------

  Pitch? _pitch(String pitchId) {
    for (final list in _pitches.values) {
      for (final p in list) {
        if (p.id == pitchId) return p;
      }
    }
    return null;
  }

  String _venueOfPitch(String pitchId) {
    for (final entry in _pitches.entries) {
      if (entry.value.any((p) => p.id == pitchId)) return entry.key;
    }
    throw AppException.fromCode('forbidden');
  }

  void _expireHolds() {
    final now = _store.now();
    for (var i = 0; i < _bookings.length; i++) {
      final b = _bookings[i];
      if (b.status == BookingStatus.pendingPayment && b.holdExpiresAt != null && !b.holdExpiresAt!.isAfter(now)) {
        _bookings[i] = b.copyWith(status: BookingStatus.expired);
      }
    }
  }

  bool _overlaps(String pitchId, DateTime start, DateTime end) {
    final now = _store.now();
    return _bookings.any((b) =>
        b.pitchId == pitchId && isLiveOwnerBooking(b, now) && b.startsAt.isBefore(end) && b.endsAt.isAfter(start));
  }

  Booking _make({
    required Pitch pitch,
    required String venueId,
    required String source,
    required BookingStatus status,
    required DateTime startsAt,
    DateTime? endsAt,
    String? userId,
    String? customerName,
    String? customerPhone,
    String? note,
    DateTime? holdExpiresAt,
  }) {
    final venue = _store.venueById(venueId)!;
    final end = endsAt ?? startsAt.add(Duration(minutes: pitch.slotMinutes));
    final minutes = end.difference(startsAt).inMinutes;
    return Booking(
      id: 'demo-owner-booking-${_nextId++}',
      pitchId: pitch.id,
      venueId: venueId,
      userId: userId,
      source: source,
      status: status,
      startsAt: startsAt,
      endsAt: end,
      priceKurus: source == 'block' ? 0 : pitch.hourlyPriceKurus * minutes ~/ 60,
      depositKurus: source == 'app' ? pitch.depositKurus : 0,
      commissionKurus: 0,
      holdExpiresAt: holdExpiresAt,
      pitchName: pitch.name,
      pitchFormat: pitch.format,
      venueName: venue.name,
      venueDistrict: venue.district,
      cancellationWindowHours: venue.cancellationWindowHours,
      customerName: customerName,
      customerPhone: customerPhone,
      note: note,
    );
  }

  @override
  Future<Booking> createManualBooking({
    required String pitchId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String source,
    String? customerName,
    String? customerPhone,
    String? note,
  }) async {
    await _latency();
    if (source != 'manual' && source != 'block') throw AppException.fromCode('invalid_source');
    final pitch = _pitch(pitchId);
    if (pitch == null) throw AppException.fromCode('forbidden');
    if (!endsAt.isAfter(startsAt) || endsAt.difference(startsAt) > const Duration(hours: 24)) {
      throw AppException.fromCode('invalid_range');
    }
    _expireHolds();
    if (_overlaps(pitchId, startsAt, endsAt)) throw AppException.fromCode('slot_taken');
    final booking = _make(
      pitch: pitch,
      venueId: _venueOfPitch(pitchId),
      source: source,
      status: BookingStatus.confirmed,
      startsAt: startsAt.toUtc(),
      endsAt: endsAt.toUtc(),
      customerName: customerName,
      customerPhone: customerPhone,
      note: note,
    );
    _bookings.add(booking);
    return booking;
  }

  int _indexOf(String bookingId) => _bookings.indexWhere((b) => b.id == bookingId);

  @override
  Future<Booking> cancelBooking(String bookingId, {String? reason}) async {
    await _latency();
    _expireHolds();
    final i = _indexOf(bookingId);
    if (i < 0) throw AppException.fromCode('forbidden');
    final b = _bookings[i];
    if (b.status != BookingStatus.confirmed && b.status != BookingStatus.pendingPayment) {
      throw AppException.fromCode('not_cancellable');
    }
    final now = _store.now();
    if (!b.startsAt.isAfter(now)) throw AppException.fromCode('slot_started');
    _bookings[i] = b.copyWith(status: BookingStatus.cancelled, cancelledAt: now);
    return _bookings[i];
  }

  @override
  Future<Booking> markAttendance(String bookingId, {required bool attended}) async {
    await _latency();
    final i = _indexOf(bookingId);
    if (i < 0) throw AppException.fromCode('forbidden');
    final b = _bookings[i];
    final marked =
        b.status == BookingStatus.confirmed || b.status == BookingStatus.completed || b.status == BookingStatus.noShow;
    if (!marked || b.source == 'block' || b.startsAt.isAfter(_store.now())) {
      throw AppException.fromCode('invalid_status');
    }
    _bookings[i] = b.copyWith(status: attended ? BookingStatus.completed : BookingStatus.noShow);
    return _bookings[i];
  }

  @override
  Future<Pitch> updatePitch({
    required String pitchId,
    required int hourlyPriceKurus,
    required int depositKurus,
    required bool isActive,
  }) async {
    await _latency();
    final venueId = _venueOfPitch(pitchId);
    final list = _pitches[venueId]!;
    final index = list.indexWhere((p) => p.id == pitchId);
    final old = list[index];
    if (hourlyPriceKurus <= 0 ||
        depositKurus < 0 ||
        !depositWithinPrice(
          depositKurus: depositKurus,
          hourlyPriceKurus: hourlyPriceKurus,
          slotMinutes: old.slotMinutes,
        )) {
      throw const AppException('invalid_range', S.depositTooHigh);
    }
    final updated = Pitch(
      id: old.id,
      name: old.name,
      format: old.format,
      isIndoor: old.isIndoor,
      hourlyPriceKurus: hourlyPriceKurus,
      depositKurus: depositKurus,
      slotMinutes: old.slotMinutes,
      sortOrder: old.sortOrder,
      isActive: isActive,
    );
    list[index] = updated;
    return updated;
  }

  // --- Seed ----------------------------------------------------------------------------------

  /// Istanbul wall-clock [hour] on the business day [daysFromToday] away, as a UTC instant.
  /// Hours below 6 belong to the next calendar day (overnight venue).
  DateTime _at(int daysFromToday, int hour) {
    final today = businessDayToday(_store.now());
    final extraDay = hour < businessDayStartHour ? 1 : 0;
    return DateTime.utc(today.year, today.month, today.day + daysFromToday + extraDay, hour).subtract(istanbulOffset);
  }

  void _seed() {
    for (final v in _venues) {
      _pitches[v.id] = List<Pitch>.of(v.pitches);
      _hours[v.id] = [
        for (var d = 1; d <= 7; d++)
          DayHours(isoWeekday: d, closed: false, openMinutes: v.openMinutes, closeMinutes: v.closeMinutes),
      ];
    }
    _contacts['demo-customer-1'] = const OwnerContact(userId: 'demo-customer-1', fullName: 'Elif Demir', phone: '+905550000101');
    _contacts['demo-customer-2'] = const OwnerContact(userId: 'demo-customer-2', fullName: 'Burak Aydın', phone: '+905550000102');
    _contacts['demo-customer-3'] = const OwnerContact(userId: 'demo-customer-3', fullName: 'Selin Koç', phone: '+905550000103');

    final v1 = _pitches['demo-venue-1']!;
    final v2 = _pitches[demoOvernightVenueId]!;
    final now = _store.now();

    void app(Pitch p, String venue, int day, int hour, String user, {BookingStatus status = BookingStatus.confirmed}) {
      _bookings.add(_make(
        pitch: p,
        venueId: venue,
        source: 'app',
        status: status,
        startsAt: _at(day, hour),
        userId: user,
        holdExpiresAt: status == BookingStatus.pendingPayment ? now.add(const Duration(minutes: 8)) : null,
      ));
    }

    void manual(Pitch p, String venue, int day, int hour, String name, String phone, {String? note}) {
      _bookings.add(_make(
        pitch: p,
        venueId: venue,
        source: 'manual',
        status: BookingStatus.confirmed,
        startsAt: _at(day, hour),
        customerName: name,
        customerPhone: phone,
        note: note,
      ));
    }

    void block(Pitch p, String venue, int day, int hour, {String? note}) {
      _bookings.add(_make(
        pitch: p,
        venueId: venue,
        source: 'block',
        status: BookingStatus.confirmed,
        startsAt: _at(day, hour),
        note: note,
      ));
    }

    // Mavi Çim (09-23): a mix for today, a finished evening yesterday and some days ahead.
    app(v1[0], 'demo-venue-1', 0, 20, 'demo-customer-1');
    app(v1[0], 'demo-venue-1', 0, 21, 'demo-customer-2');
    manual(v1[0], 'demo-venue-1', 0, 18, 'Ahmet Yılmaz', '+905550000201', note: 'Kalan ücret sahada ödenecek');
    block(v1[1], 'demo-venue-1', 0, 19, note: 'Zemin bakımı');
    app(v1[1], 'demo-venue-1', 0, 20, 'demo-customer-3', status: BookingStatus.pendingPayment);
    manual(v1[2], 'demo-venue-1', 0, 22, 'Mehmet Kaya', '+905550000202');
    app(v1[0], 'demo-venue-1', -1, 20, 'demo-customer-2');
    manual(v1[1], 'demo-venue-1', -1, 21, 'Cem Arslan', '+905550000203');
    app(v1[0], 'demo-venue-1', 1, 19, 'demo-customer-1');
    manual(v1[2], 'demo-venue-1', 1, 21, 'Kerem Şahin', '+905550000204');
    block(v1[1], 'demo-venue-1', 2, 18);
    app(v1[1], 'demo-venue-1', 3, 20, 'demo-customer-3');

    // Gece Kuşu (12-06, overnight).
    app(v2[0], demoOvernightVenueId, 0, 21, 'demo-customer-2');
    manual(v2[1], demoOvernightVenueId, 0, 23, 'Oğuz Tan', '+905550000205', note: 'Vardiya çıkışı');
    block(v2[1], demoOvernightVenueId, 0, 15, note: 'Turnuva hazırlığı');
    app(v2[0], demoOvernightVenueId, 0, 1, 'demo-customer-1');
    app(v2[0], demoOvernightVenueId, 1, 20, 'demo-customer-3');
    manual(v2[0], demoOvernightVenueId, -1, 22, 'Hakan Çelik', '+905550000206');
  }
}
