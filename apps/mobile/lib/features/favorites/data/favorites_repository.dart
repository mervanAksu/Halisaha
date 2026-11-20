import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/favorite_venue.dart';

class FavoritesRepository {
  FavoritesRepository(this._client);

  final SupabaseClient _client;

  Future<Set<String>> fetchFavoriteIds() => guard(() async {
        final response = await _client.from('favorites').select('venue_id');
        return asRows(response).map((r) => r['venue_id'] as String).toSet();
      });

  Future<List<FavoriteVenue>> fetchFavorites() => guard(() async {
        final response = await _client
            .from('favorites')
            .select('created_at, venues(id, name, district, address, cover_photo_path)')
            .order('created_at', ascending: false);
        return asRows(response).map(FavoriteVenue.fromJson).whereType<FavoriteVenue>().toList();
      });

  /// `user_id` defaults to `auth.uid()` on the server.
  Future<void> add(String venueId) => guard(() async {
        try {
          await _client.from('favorites').insert({'venue_id': venueId});
        } on PostgrestException catch (e) {
          if (e.code == '23505') return; // already a favourite
          rethrow;
        }
      });

  Future<void> remove(String venueId) => guard(() async {
        await _client.from('favorites').delete().eq('venue_id', venueId);
      });
}
