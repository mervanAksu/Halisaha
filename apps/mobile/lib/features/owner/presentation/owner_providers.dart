import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import '../data/owner_repository.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return SupabaseOwnerRepository(ref.watch(supabaseClientProvider));
});

final ownerVenuesProvider = FutureProvider.autoDispose<List<OwnerVenue>>((ref) {
  return ref.watch(ownerRepositoryProvider).fetchMyVenues();
});

/// Venue chosen in the switcher; null = the first venue of the list.
final selectedOwnerVenueIdProvider = StateProvider<String?>((ref) => null);

final ownerPitchesProvider = FutureProvider.autoDispose.family<List<Pitch>, String>((ref, venueId) {
  return ref.watch(ownerRepositoryProvider).fetchPitches(venueId);
});

final ownerHoursProvider = FutureProvider.autoDispose.family<List<DayHours>, String>((ref, venueId) {
  return ref.watch(ownerRepositoryProvider).fetchHours(venueId);
});

/// Key of [ownerDayBookingsProvider]: a venue and one business day (`yyyy-MM-dd`).
typedef OwnerDayKey = ({String venueId, String isoDate});

final ownerDayBookingsProvider = FutureProvider.autoDispose.family<List<Booking>, OwnerDayKey>((ref, key) {
  final parts = key.isoDate.split('-').map(int.parse).toList();
  final window = ownerDayWindow(DateTime.utc(parts[0], parts[1], parts[2]));
  return ref.watch(ownerRepositoryProvider).fetchBookings(
        venueId: key.venueId,
        fromUtc: window.fromUtc,
        toUtc: window.toUtc,
      );
});

/// Bookings of the next 60 days, oldest first ("Rezervasyonlar" tab).
const Duration ownerUpcomingHorizon = Duration(days: 60);

final ownerUpcomingProvider = FutureProvider.autoDispose.family<List<Booking>, String>((ref, venueId) {
  final now = DateTime.now().toUtc();
  return ref.watch(ownerRepositoryProvider).fetchBookings(
        venueId: venueId,
        fromUtc: now.subtract(const Duration(hours: 3)),
        toUtc: now.add(ownerUpcomingHorizon),
      );
});

/// Name and phone of an app customer (null when the RPC does not return the user).
final ownerContactProvider = FutureProvider.autoDispose.family<OwnerContact?, String>((ref, userId) async {
  final list = await ref.watch(ownerRepositoryProvider).fetchContacts([userId]);
  for (final c in list) {
    if (c.userId == userId) return c;
  }
  return null;
});

/// Writes of the owner panel. Each one refreshes the lists that show the changed data.
class OwnerActions {
  OwnerActions(this._ref);

  final Ref _ref;

  OwnerRepository get _repo => _ref.read(ownerRepositoryProvider);

  void _refreshBookings() {
    _ref.invalidate(ownerDayBookingsProvider);
    _ref.invalidate(ownerUpcomingProvider);
  }

  Future<void> createManual({
    required Pitch pitch,
    required DateTime startsAt,
    required String customerName,
    String? customerPhone,
    String? note,
  }) async {
    await _repo.createManualBooking(
      pitchId: pitch.id,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: pitch.slotMinutes)),
      source: 'manual',
      customerName: customerName,
      customerPhone: customerPhone,
      note: note,
    );
    _refreshBookings();
  }

  Future<void> closeSlot({required Pitch pitch, required DateTime startsAt, String? note}) async {
    await _repo.createManualBooking(
      pitchId: pitch.id,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: pitch.slotMinutes)),
      source: 'block',
      note: note,
    );
    _refreshBookings();
  }

  Future<void> cancel(Booking booking) async {
    await _repo.cancelBooking(booking.id);
    _refreshBookings();
  }

  Future<void> markAttendance(Booking booking, {required bool attended}) async {
    await _repo.markAttendance(booking.id, attended: attended);
    _refreshBookings();
  }

  Future<void> updatePitch({
    required Pitch pitch,
    required int hourlyPriceKurus,
    required int depositKurus,
    required bool isActive,
  }) async {
    await _repo.updatePitch(
      pitchId: pitch.id,
      hourlyPriceKurus: hourlyPriceKurus,
      depositKurus: depositKurus,
      isActive: isActive,
    );
    _ref.invalidate(ownerPitchesProvider);
  }

  Future<void> saveHours(String venueId, List<DayHours> days) async {
    await _repo.saveHours(venueId, days);
    _ref.invalidate(ownerHoursProvider);
  }
}

final ownerActionsProvider = Provider<OwnerActions>((ref) => OwnerActions(ref));
