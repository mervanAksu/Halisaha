import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/venues_repository.dart';
import '../domain/slot.dart';
import '../domain/venue_detail.dart';
import '../domain/venue_summary.dart';

final venuesRepositoryProvider = Provider<VenuesRepository>((ref) {
  return VenuesRepository(ref.watch(supabaseClientProvider));
});

// --- Home list filters -------------------------------------------------------

/// Debounced search text (the debounce lives in the search field widget).
final venueSearchProvider = StateProvider<String>((ref) => '');

/// Selected district chip; null = all districts.
final venueDistrictProvider = StateProvider<String?>((ref) => null);

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

final venueListProvider = FutureProvider.autoDispose<List<VenueSummary>>((ref) {
  final search = ref.watch(venueSearchProvider);
  final district = ref.watch(venueDistrictProvider);
  final location = ref.watch(locationProvider);
  return ref.watch(venuesRepositoryProvider).listVenues(
        search: search,
        district: district,
        lat: location.lat,
        lng: location.lng,
      );
});

/// Distinct districts for the filter chips (unfiltered list).
final districtsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final venues = await ref.watch(venuesRepositoryProvider).listVenues();
  final set = venues.map((v) => v.district).where((d) => d.isNotEmpty).toSet().toList()..sort();
  return set;
});

final venueDetailProvider = FutureProvider.autoDispose.family<VenueDetail, String>((ref, venueId) {
  return ref.watch(venuesRepositoryProvider).fetchVenue(venueId);
});

/// Key for [availabilityProvider]: records have value equality, so this works as a family argument.
typedef AvailabilityKey = ({String pitchId, String isoDate});

final availabilityProvider = FutureProvider.autoDispose.family<List<Slot>, AvailabilityKey>((ref, key) {
  return ref.watch(venuesRepositoryProvider).fetchAvailability(pitchId: key.pitchId, isoDate: key.isoDate);
});
