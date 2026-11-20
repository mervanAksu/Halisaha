import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../venues/presentation/venues_providers.dart';
import '../data/favorites_repository.dart';
import '../domain/favorite_venue.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(supabaseClientProvider));
});

final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(favoritesRepositoryProvider).fetchFavoriteIds();
});

final favoriteVenuesProvider = FutureProvider.autoDispose<List<FavoriteVenue>>((ref) {
  return ref.watch(favoritesRepositoryProvider).fetchFavorites();
});

/// Write side: toggles a favourite and refreshes every list that shows it.
class FavoritesActions {
  FavoritesActions(this._ref);

  final Ref _ref;

  Future<void> setFavorite(String venueId, {required bool favorite}) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    if (favorite) {
      await repo.add(venueId);
    } else {
      await repo.remove(venueId);
    }
    _ref.invalidate(favoriteIdsProvider);
    _ref.invalidate(favoriteVenuesProvider);
    _ref.invalidate(venueListProvider);
  }
}

final favoritesActionsProvider = Provider<FavoritesActions>((ref) => FavoritesActions(ref));
