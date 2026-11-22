import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/slot.dart';
import '../domain/venue_detail.dart';
import '../domain/venue_location.dart';
import '../domain/venue_summary.dart';

class VenuesRepository {
  VenuesRepository(this._client);

  final SupabaseClient _client;

  /// RPC `list_venues`. Null / empty filters are omitted.
  Future<List<VenueSummary>> listVenues({
    String? search,
    String? city,
    List<String>? districts,
    double? lat,
    double? lng,
  }) =>
      guard(() async {
        final params = <String, dynamic>{};
        if (search != null && search.trim().isNotEmpty) params['p_search'] = search.trim();
        if (city != null && city.isNotEmpty) params['p_city'] = city;
        if (districts != null && districts.isNotEmpty) params['p_districts'] = districts;
        if (lat != null && lng != null) {
          params['p_lat'] = lat;
          params['p_lng'] = lng;
        }
        final response = await _client.rpc('list_venues', params: params);
        return asRows(response).map(VenueSummary.fromJson).toList();
      });

  /// RPC `list_venue_locations`: provinces / districts that currently have venues.
  Future<List<VenueLocation>> listVenueLocations() => guard(() async {
        final response = await _client.rpc('list_venue_locations');
        return asRows(response).map(VenueLocation.fromJson).toList();
      });

  Future<VenueDetail> fetchVenue(String venueId) => guard(() async {
        final row = await _client
            .from('venues')
            .select(
              'id, name, description, city, district, address, lat, lng, phone, cover_photo_path, photo_paths, '
              'amenities, cancellation_window_hours, '
              'pitches(id, venue_id, name, format, is_indoor, hourly_price_kurus, deposit_kurus, slot_minutes, is_active, sort_order)',
            )
            .eq('id', venueId)
            .maybeSingle();
        if (row == null) throw AppException.fromCode('venue_not_found');
        return VenueDetail.fromJson(row);
      });

  /// RPC `get_availability`. [isoDate] is the venue business day, `yyyy-MM-dd`.
  Future<List<Slot>> fetchAvailability({required String pitchId, required String isoDate}) => guard(() async {
        final response = await _client.rpc('get_availability', params: {'p_pitch_id': pitchId, 'p_date': isoDate});
        return asRows(response).map(Slot.fromJson).toList();
      });
}
