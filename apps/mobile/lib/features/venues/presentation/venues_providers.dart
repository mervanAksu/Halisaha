import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/security/secure_local_storage.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/formatters.dart';
import '../data/venues_repository.dart';
import '../domain/location_filter.dart';
import '../domain/slot.dart';
import '../domain/slot_groups.dart';
import '../domain/venue_detail.dart';
import '../domain/venue_location.dart';
import '../domain/venue_summary.dart';

final venuesRepositoryProvider = Provider<VenuesRepository>((ref) {
  return VenuesRepository(ref.watch(supabaseClientProvider));
});

// --- Home list filters -------------------------------------------------------

/// Debounced search text (the debounce lives in the search field widget).
final venueSearchProvider = StateProvider<String>((ref) => '');

/// Device-local key/value store (platform keystore). Overridden in demo mode and tests.
final keyValueStoreProvider = Provider<SecureKeyValueStore>((ref) => FlutterSecureKeyValueStore());

/// Storage key of the persisted [LocationFilter] (JSON).
const String locationFilterStorageKey = 'location_filter_v1';

/// Province / district filter of the home list. Persisted on device and restored on start;
/// a saved province that no longer has venues falls back to "all".
class LocationFilterNotifier extends Notifier<LocationFilter> {
  bool _touched = false;

  /// Completes when the saved filter has been restored (list loading waits for it).
  late Future<void> ready;

  @override
  LocationFilter build() {
    ready = _restore();
    return LocationFilter.none;
  }

  Future<void> _restore() async {
    try {
      final saved = LocationFilter.fromJsonString(
        await ref.read(keyValueStoreProvider).read(locationFilterStorageKey).timeout(const Duration(seconds: 2)),
      );
      if (!saved.isActive || _touched) return;
      var restored = saved;
      try {
        final locations = await ref
            .read(venuesRepositoryProvider)
            .listVenueLocations()
            .timeout(const Duration(seconds: 5));
        final cityExists = locations.any((l) => l.city == saved.city);
        final districts = districtOptions(locations, saved.city!).map((d) => d.district).toSet();
        restored = cityExists
            ? LocationFilter(city: saved.city, districts: saved.districts.intersection(districts))
            : LocationFilter.none;
      } catch (_) {
        // Offline: keep what was saved; the list shows its own error if the network is really down.
      }
      if (_touched) return;
      state = restored;
      if (restored != saved) await _persist(restored);
    } catch (_) {
      // Unreadable storage: stay on "all".
    }
  }

  Future<void> apply({required String? city, Set<String> districts = const <String>{}}) {
    _touched = true;
    final next = city == null ? LocationFilter.none : LocationFilter(city: city, districts: Set.unmodifiable(districts));
    state = next;
    return _persist(next);
  }

  Future<void> clear() => apply(city: null);

  Future<void> _persist(LocationFilter filter) async {
    try {
      final store = ref.read(keyValueStoreProvider);
      if (filter.isActive) {
        await store.write(locationFilterStorageKey, filter.toJsonString());
      } else {
        await store.delete(locationFilterStorageKey);
      }
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final locationFilterProvider = NotifierProvider<LocationFilterNotifier, LocationFilter>(LocationFilterNotifier.new);

/// Provinces / districts that have venues (feeds the picker sheet).
final venueLocationsProvider = FutureProvider.autoDispose<List<VenueLocation>>((ref) {
  return ref.watch(venuesRepositoryProvider).listVenueLocations();
});

// --- Location ----------------------------------------------------------------

enum LocationStatus { unknown, loading, granted, denied, deniedForever, serviceDisabled, error }

class LocationState {
  const LocationState({this.status = LocationStatus.unknown, this.lat, this.lng});

  final LocationStatus status;
  final double? lat;
  final double? lng;

  bool get hasFix => lat != null && lng != null;
}

/// Optional user location. Never blocks the app: every failure leaves the list usable.
class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// Fetches a position only if permission was already granted; never prompts.
  Future<void> initSilently() async {
    if (AppConfig.demoMode) return; // demo: never touch geolocation
    if (state.status != LocationStatus.unknown) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await _fetch();
      } else if (permission == LocationPermission.deniedForever) {
        state = const LocationState(status: LocationStatus.deniedForever);
      } else {
        state = const LocationState(status: LocationStatus.denied);
      }
    } catch (_) {
      state = const LocationState(status: LocationStatus.error);
    }
  }

  /// Asks for permission (user tapped the banner) and fetches the position.
  Future<void> request() async {
    if (AppConfig.demoMode) return;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        state = const LocationState(status: LocationStatus.serviceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        state = const LocationState(status: LocationStatus.deniedForever);
      } else if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        state = const LocationState(status: LocationStatus.denied);
      } else {
        await _fetch();
      }
    } catch (_) {
      state = const LocationState(status: LocationStatus.error);
    }
  }

  Future<void> openSettings() async {
    if (state.status == LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _fetch() async {
    state = const LocationState(status: LocationStatus.loading);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );
      // ~110 m precision is plenty for sorting venues and avoids needless refetches.
      state = LocationState(
        status: LocationStatus.granted,
        lat: double.parse(position.latitude.toStringAsFixed(3)),
        lng: double.parse(position.longitude.toStringAsFixed(3)),
      );
    } catch (_) {
      state = const LocationState(status: LocationStatus.error);
    }
  }
}

final locationProvider = NotifierProvider<LocationController, LocationState>(LocationController.new);

// --- Reads -------------------------------------------------------------------

final venueListProvider = FutureProvider.autoDispose<List<VenueSummary>>((ref) async {
  final search = ref.watch(venueSearchProvider);
  ref.watch(locationFilterProvider);
  final location = ref.watch(locationProvider);
  // Wait for the saved filter so the first list is not fetched unfiltered.
  await ref.read(locationFilterProvider.notifier).ready;
  final filter = ref.read(locationFilterProvider);
  return ref.read(venuesRepositoryProvider).listVenues(
        search: search,
        city: filter.city,
        districts: filter.districtsParam,
        lat: location.lat,
        lng: location.lng,
      );
});

final venueDetailProvider = FutureProvider.autoDispose.family<VenueDetail, String>((ref, venueId) {
  return ref.watch(venuesRepositoryProvider).fetchVenue(venueId);
});

/// Key for [availabilityProvider]: records have value equality, so this works as a family argument.
typedef AvailabilityKey = ({String pitchId, String isoDate});

final availabilityProvider = FutureProvider.autoDispose.family<List<Slot>, AvailabilityKey>((ref, key) {
  return ref.watch(venuesRepositoryProvider).fetchAvailability(pitchId: key.pitchId, isoDate: key.isoDate);
});

/// Key for [nearestAvailableDayProvider]: look at the [maxDays] days after [fromIsoDate].
typedef NearestDayKey = ({String pitchId, String fromIsoDate, int maxDays});

/// First day after `fromIsoDate` (within `maxDays`) that has a bookable slot, or null.
/// Reuses [availabilityProvider], so days already looked at are served from its cache.
final nearestAvailableDayProvider = FutureProvider.autoDispose.family<DateTime?, NearestDayKey>((ref, key) async {
  final from = parseIsoDate(key.fromIsoDate);
  for (var i = 1; i <= key.maxDays; i++) {
    final day = DateTime.utc(from.year, from.month, from.day + i);
    final slots = await ref.watch(availabilityProvider((pitchId: key.pitchId, isoDate: formatIsoDate(day))).future);
    if (hasAvailableSlot(slots)) return day;
  }
  return null;
});
