import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/utils/json_utils.dart';
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';

/// Everything the in-app owner panel needs from the backend. The Supabase implementation talks to
/// the owner RPCs and the RLS-protected tables of docs/API_CONTRACT.md; the demo build swaps in an
/// in-memory implementation.
abstract class OwnerRepository {
  /// Venues owned by the signed-in user.
  Future<List<OwnerVenue>> fetchMyVenues();

  /// All pitches of a venue, inactive ones included, in display order.
  Future<List<Pitch>> fetchPitches(String venueId);

  /// Opening hours for ISO weekdays 1..7 (always seven entries; a missing row is a closed day).
  Future<List<DayHours>> fetchHours(String venueId);

  /// Replaces the weekly hours: open days are upserted, closed days deleted.
  Future<void> saveHours(String venueId, List<DayHours> days);

  /// Bookings of a venue whose start lies in `[fromUtc, toUtc)`, oldest first.
  Future<List<Booking>> fetchBookings({required String venueId, required DateTime fromUtc, required DateTime toUtc});

  /// RPC `owner_customer_contacts`.
  Future<List<OwnerContact>> fetchContacts(List<String> userIds);

  /// RPC `owner_create_manual_booking` (`source` is `manual` or `block`).
  Future<Booking> createManualBooking({
    required String pitchId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String source,
    String? customerName,
    String? customerPhone,
    String? note,
  });

  /// RPC `owner_cancel_booking`.
  Future<Booking> cancelBooking(String bookingId, {String? reason});

  /// RPC `owner_mark_attendance`.
  Future<Booking> markAttendance(String bookingId, {required bool attended});

  /// Updates price, deposit and availability of a pitch (table `pitches`, owner RLS).
  Future<Pitch> updatePitch({
    required String pitchId,
    required int hourlyPriceKurus,
    required int depositKurus,
    required bool isActive,
  });
}

class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(this._client);

  final SupabaseClient _client;

  static const String _pitchColumns =
      'id, venue_id, name, format, is_indoor, hourly_price_kurus, deposit_kurus, slot_minutes, is_active, sort_order';

  @override
  Future<List<OwnerVenue>> fetchMyVenues() => guard(() async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) throw AppException.fromCode('not_authenticated');
        final response = await _client
            .from('venues')
            .select('id, name, district')
            .eq('owner_id', uid)
            .order('name', ascending: true);
        return asRows(response).map(OwnerVenue.fromJson).toList();
      });

  @override
  Future<List<Pitch>> fetchPitches(String venueId) => guard(() async {
        final response = await _client
            .from('pitches')
            .select(_pitchColumns)
            .eq('venue_id', venueId)
            .order('sort_order', ascending: true)
            .order('name', ascending: true);
        return asRows(response).map(Pitch.fromJson).toList();
      });

  @override
  Future<List<DayHours>> fetchHours(String venueId) => guard(() async {
        final response = await _client
            .from('venue_hours')
            .select('iso_weekday, open_time, close_time')
            .eq('venue_id', venueId);
        final byDay = <int, DayHours>{};
        for (final row in asRows(response)) {
          final day = asInt(row['iso_weekday']);
          byDay[day] = DayHours(
            isoWeekday: day,
            closed: false,
            openMinutes: DayHours.parseMinutes(parseHourMinute(row['open_time'])!),
            closeMinutes: DayHours.parseMinutes(parseHourMinute(row['close_time'])!),
          );
        }
        return [for (var d = 1; d <= 7; d++) byDay[d] ?? DayHours.closed(d)];
      });

  @override
  Future<void> saveHours(String venueId, List<DayHours> days) => guard(() async {
        final open = days.where((d) => !d.closed).toList();
        final closedDays = days.where((d) => d.closed).map((d) => d.isoWeekday).toList();
        if (open.isNotEmpty) {
          await _client.from('venue_hours').upsert(
            [
              for (final d in open)
                {
                  'venue_id': venueId,
                  'iso_weekday': d.isoWeekday,
                  'open_time': d.openSql,
                  'close_time': d.closeSql,
                },
            ],
            onConflict: 'venue_id,iso_weekday',
          );
        }
        if (closedDays.isNotEmpty) {
          await _client.from('venue_hours').delete().eq('venue_id', venueId).inFilter('iso_weekday', closedDays);
        }
      });

  @override
  Future<List<Booking>> fetchBookings({
    required String venueId,
    required DateTime fromUtc,
    required DateTime toUtc,
  }) =>
      guard(() async {
        final response = await _client
            .from('bookings')
            .select('*')
            .eq('venue_id', venueId)
            .gte('starts_at', fromUtc.toUtc().toIso8601String())
            .lt('starts_at', toUtc.toUtc().toIso8601String())
            .order('starts_at', ascending: true)
            .limit(500);
        return asRows(response).map(Booking.fromJson).toList();
      });

  @override
  Future<List<OwnerContact>> fetchContacts(List<String> userIds) => guard(() async {
        if (userIds.isEmpty) return const <OwnerContact>[];
        final response = await _client.rpc('owner_customer_contacts', params: {'p_user_ids': userIds});
        return asRows(response).map(OwnerContact.fromJson).toList();
      });

  @override
  Future<Booking> createManualBooking({
    required String pitchId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String source,
    String? customerName,
    String? customerPhone,
    String? note,
  }) =>
      guard(() async {
        final params = <String, dynamic>{
          'p_pitch_id': pitchId,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
          'p_ends_at': endsAt.toUtc().toIso8601String(),
          'p_source': source,
        };
        if (customerName != null && customerName.isNotEmpty) params['p_customer_name'] = customerName;
        if (customerPhone != null && customerPhone.isNotEmpty) params['p_customer_phone'] = customerPhone;
        if (note != null && note.isNotEmpty) params['p_note'] = note;
        final response = await _client.rpc('owner_create_manual_booking', params: params);
        return Booking.fromJson(asRow(response));
      });

  @override
  Future<Booking> cancelBooking(String bookingId, {String? reason}) => guard(() async {
        final params = <String, dynamic>{'p_booking_id': bookingId};
        if (reason != null && reason.isNotEmpty) params['p_reason'] = reason;
        final response = await _client.rpc('owner_cancel_booking', params: params);
        return Booking.fromJson(asRow(response));
      });

  @override
  Future<Booking> markAttendance(String bookingId, {required bool attended}) => guard(() async {
        final response = await _client.rpc('owner_mark_attendance', params: {
          'p_booking_id': bookingId,
          'p_status': attended ? 'completed' : 'no_show',
        });
        return Booking.fromJson(asRow(response));
      });

  @override
  Future<Pitch> updatePitch({
    required String pitchId,
    required int hourlyPriceKurus,
    required int depositKurus,
    required bool isActive,
  }) =>
      guard(() async {
        final current = await _client.from('pitches').select('slot_minutes').eq('id', pitchId).single();
        final slotMinutes = asInt(current['slot_minutes']);
        if (!depositWithinPrice(depositKurus: depositKurus, hourlyPriceKurus: hourlyPriceKurus, slotMinutes: slotMinutes)) {
          throw const AppException('invalid_range', S.depositTooHigh);
        }
        final row = await _client
            .from('pitches')
            .update({
              'hourly_price_kurus': hourlyPriceKurus,
              'deposit_kurus': depositKurus,
              'is_active': isActive,
            })
            .eq('id', pitchId)
            .select(_pitchColumns)
            .single();
        return Pitch.fromJson(row);
      });
}
