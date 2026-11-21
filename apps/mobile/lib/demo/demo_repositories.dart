import '../core/errors/app_exception.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/booking/data/booking_repository.dart';
import '../features/booking/domain/booking.dart';
import '../features/booking/domain/cancel_result.dart';
import '../features/booking/domain/payment_session.dart';
import '../features/favorites/data/favorites_repository.dart';
import '../features/favorites/domain/favorite_venue.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/profile.dart';
import '../features/venues/data/venues_repository.dart';
import '../features/venues/domain/slot.dart';
import '../features/venues/domain/venue_detail.dart';
import '../features/venues/domain/venue_summary.dart';
import 'demo_data.dart';
import 'demo_store.dart';

/// Short artificial latency so loading states are visible and the UI feels like a real backend.
Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

/// Lower-case, diacritic-free form for search ("İstanbul" -> "istanbul", "Ataşehir" -> "atasehir").
String foldTr(String input) {
  const map = <String, String>{
    'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(map[ch] ?? ch.toLowerCase());
  }
  return buffer.toString();
}

class DemoAuthRepository implements AuthRepository {
  @override
  Future<void> sendOtp(String e164Phone) async {}

  @override
  Future<void> verifyOtp({required String e164Phone, required String code}) async {}

  @override
  Future<void> signOut() async => throw demoDisabledException();
}

class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this._store);

  final DemoStore _store;

  @override
  Future<Profile> fetch(String userId) async {
    await _latency();
    return _store.profile;
  }

  @override
  Future<Profile> completeOnboarding({
    required String userId,
    required String fullName,
    required bool marketingConsent,
  }) async {
    _store.profile = _store.profile.copyWith(
      fullName: fullName.trim(),
      marketingConsent: marketingConsent,
      kvkkAckAt: _store.now().toUtc(),
    );
    return _store.profile;
  }

  @override
  Future<Profile> updateName({required String userId, required String fullName}) async {
    _store.profile = _store.profile.copyWith(fullName: fullName.trim());
    return _store.profile;
  }

  @override
  Future<void> deleteAccount() async => throw demoDisabledException();
}

class DemoVenuesRepository implements VenuesRepository {
  DemoVenuesRepository(this._store);

  final DemoStore _store;

  @override
  Future<List<VenueSummary>> listVenues({String? search, String? district, double? lat, double? lng}) async {
    await _latency();
    final query = foldTr((search ?? '').trim());
    final list = _store.venues.where((v) {
      if (district != null && district.isNotEmpty && v.district != district) return false;
      if (query.isEmpty) return true;
      return foldTr('${v.name} ${v.district} ${v.address}').contains(query);
    }).toList()
      ..sort((a, b) => foldTr(a.name).compareTo(foldTr(b.name)));
    return list.map((v) => v.toSummary(isFavorite: _store.favoriteIds.contains(v.id))).toList();
  }

  @override
  Future<VenueDetail> fetchVenue(String venueId) async {
    await _latency();
    final venue = _store.venueById(venueId);
    if (venue == null) throw AppException.fromCode('venue_not_found');
    return venue.toDetail();
  }

  @override
  Future<List<Slot>> fetchAvailability({required String pitchId, required String isoDate}) async {
    await _latency();
    return _store.availability(pitchId, isoDate);
  }
}

class DemoFavoritesRepository implements FavoritesRepository {
  DemoFavoritesRepository(this._store);

  final DemoStore _store;

  @override
  Future<Set<String>> fetchFavoriteIds() async => _store.favoriteIds.toSet();

  @override
  Future<List<FavoriteVenue>> fetchFavorites() async {
    await _latency();
    return _store.favoriteIds.reversed
        .map(_store.venueById)
        .whereType<DemoVenue>()
        .map((v) => FavoriteVenue(venueId: v.id, name: v.name, district: v.district, address: v.address))
        .toList();
  }

  @override
  Future<void> add(String venueId) async => _store.setFavorite(venueId, favorite: true);

  @override
  Future<void> remove(String venueId) async => _store.setFavorite(venueId, favorite: false);
}

class DemoBookingRepository implements BookingRepository {
  DemoBookingRepository(this._store);

  final DemoStore _store;

  @override
  Future<Booking> createHold({required String pitchId, required DateTime startsAt}) async {
    await _latency();
    return _store.createHold(pitchId, startsAt);
  }

  @override
  Future<PaymentSession> startPayment(String bookingId) async {
    await _latency();
    return _store.startPayment(bookingId);
  }

  @override
  Future<Booking> fetchBooking(String bookingId) async => _store.fetchBooking(bookingId);

  @override
  Future<List<Booking>> fetchMyBookings() async {
    await _latency();
    return _store.myBookings();
  }

  @override
  Future<CancelResult> cancel(String bookingId, {String? reason}) async {
    await _latency();
    return _store.cancel(bookingId);
  }

  @override
  Future<String?> fetchLatestPaymentStatus(String bookingId) async => _store.latestPaymentStatus(bookingId);
}
