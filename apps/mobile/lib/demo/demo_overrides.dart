import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../core/app_mode/app_mode.dart';
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

/// Whether the demo session is signed in. Starts signed out, exactly like a fresh install of the real
/// app, so "Maç yapacağım" asks for a phone number. Only the `?mode=` preview links (store
/// screenshots) start signed in. Sign-in, sign-out and the owner login flip it.
final demoSignedInProvider = StateProvider<bool>((ref) => false);

/// Root `ProviderScope` overrides for the backend-free demo. With these in place no provider ever
/// reads `supabaseClientProvider`, so `Supabase.instance` is never touched.
///
/// [initialMode] pre-sets the app mode (web preview `?mode=player|owner`, store screenshots); the owner
/// preset also makes the signed-in demo user an owner.
List<Override> demoOverrides(DemoStore store, {AppMode? initialMode}) {
  if (initialMode == AppMode.owner) store.setOwnerMode(true);
  return <Override>[
    demoStoreProvider.overrideWithValue(store),
    if (initialMode != null) demoSignedInProvider.overrideWith((ref) => true),
    authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
    currentUserIdProvider.overrideWith((ref) => ref.watch(demoSignedInProvider) ? DemoStore.userId : null),
    authRepositoryProvider.overrideWith(
      (ref) => DemoAuthRepository(
        store: store,
        onAuthChanged: (signedIn) {
          ref.read(demoSignedInProvider.notifier).state = signedIn;
          // The role may have changed while the session flag did not (e.g. owner login while signed in).
          ref.invalidate(profileProvider);
        },
      ),
    ),
    profileRepositoryProvider.overrideWithValue(DemoProfileRepository(store)),
    venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(store)),
    keyValueStoreProvider.overrideWithValue(
      InMemoryKeyValueStore(initial: {if (initialMode != null) appModeStorageKey: initialMode.name}),
    ),
    favoritesRepositoryProvider.overrideWithValue(DemoFavoritesRepository(store)),
    bookingRepositoryProvider.overrideWithValue(DemoBookingRepository(store)),
    ownerRepositoryProvider.overrideWithValue(DemoOwnerRepository(store)),
  ];
}
