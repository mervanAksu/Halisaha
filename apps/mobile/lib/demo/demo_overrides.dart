import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../core/security/secure_local_storage.dart';
import '../core/supabase/supabase_providers.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/booking/presentation/booking_providers.dart';
import '../features/owner/presentation/owner_providers.dart';
import '../features/favorites/presentation/favorites_providers.dart';
import '../features/profile/presentation/profile_providers.dart';
import '../features/venues/presentation/venues_providers.dart';
import 'demo_owner_repository.dart';
import 'demo_repositories.dart';
import 'demo_store.dart';

/// Gives the demo payment screen access to the in-memory backend. Throws outside demo mode.
final demoStoreProvider = Provider<DemoStore>((ref) => throw StateError('demoStoreProvider is only available in demo mode'));

/// Root `ProviderScope` overrides for the backend-free demo. With these in place no provider ever
/// reads `supabaseClientProvider`, so `Supabase.instance` is never touched.
List<Override> demoOverrides(DemoStore store) {
  return <Override>[
    demoStoreProvider.overrideWithValue(store),
    // Signed in as the demo user for the whole session.
    authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
    currentUserIdProvider.overrideWithValue(DemoStore.userId),
    authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
    profileRepositoryProvider.overrideWithValue(DemoProfileRepository(store)),
    venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(store)),
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    favoritesRepositoryProvider.overrideWithValue(DemoFavoritesRepository(store)),
    bookingRepositoryProvider.overrideWithValue(DemoBookingRepository(store)),
    ownerRepositoryProvider.overrideWithValue(DemoOwnerRepository(store)),
  ];
}
