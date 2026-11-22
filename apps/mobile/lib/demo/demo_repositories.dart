import '../core/errors/app_exception.dart';
import '../core/utils/turkish.dart';
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
import '../features/venues/domain/venue_location.dart';
import '../features/venues/domain/venue_summary.dart';
import 'demo_data.dart';
import 'demo_store.dart';

export '../core/utils/turkish.dart' show foldTr;

/// Short artificial latency so loading states are visible and the UI feels like a real backend.
Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

/// Demo auth: nothing is verified. A phone code signs in the customer, any e-mail/password signs in
/// the demo owner (ADR-12); [onAuthChanged] flips the demo session flag the providers watch.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({required DemoStore store, required void Function(bool signedIn) onAuthChanged})
      : _store = store,
        _onAuthChanged = onAuthChanged;

  final DemoStore _store;
  final void Function(bool signedIn) _onAuthChanged;

  @override
  Future<void> sendOtp(String e164Phone) async {}

  @override
  Future<void> verifyOtp({required String e164Phone, required String code}) async {
    _store.setOwnerMode(false);
    _onAuthChanged(true);
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    _store.setOwnerMode(true);
    _onAuthChanged(true);
  }

  @override
  Future<void> signOut() async => _onAuthChanged(false);
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
  Future<List<VenueSummary>> listVenues({
    String? search,
    String? city,
    List<String>? districts,
    double? lat,
    double? lng,
  }) async {
    await _latency();
    final query = foldTr((search ?? '').trim());
    final hasCity = city != null && city.isNotEmpty;
    final wanted = districts ?? const <String>[];
    final list = _store.venues.where((v) {
      if (hasCity && v.city != city) return false;
      if (wanted.isNotEmpty && !wanted.contains(v.district)) return false;
      if (query.isEmpty) return true;
      return foldTr('${v.name} ${v.district} ${v.city} ${v.address}').contains(query);
    }).toList()
      ..sort((a, b) => foldTr(a.name).compareTo(foldTr(b.name)));
    return list.map((v) => v.toSummary(isFavorite: _store.favoriteIds.contains(v.id))).toList();
  }

  @override
  Future<List<VenueLocation>> listVenueLocations() async {
    await _latency();
    final counts = <(String, String), int>{};
    for (final v in _store.venues) {
      counts.update((v.city, v.district), (n) => n + 1, ifAbsent: () => 1);
    }
    final result = [
      for (final e in counts.entries) VenueLocation(city: e.key.$1, district: e.key.$2, venueCount: e.value),
    ]..sort((a, b) {
        final byCity = compareTr(a.city, b.city);
        return byCity != 0 ? byCity : compareTr(a.district, b.district);
      });
    return result;
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
