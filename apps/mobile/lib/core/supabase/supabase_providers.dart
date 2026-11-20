import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single Supabase client. Repositories receive it through this provider;
/// widgets never touch it directly.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Auth events (sign in, sign out, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Id of the signed-in user, or null. Returning the id (a String) instead of the
/// `User` object keeps dependants from rebuilding on every token refresh.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
