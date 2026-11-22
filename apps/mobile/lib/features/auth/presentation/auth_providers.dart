import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

/// True while the signed-in session must still pass the TOTP step (next aal2, current aal1).
/// Re-evaluated on auth events; invalidate it after a successful verification. A failed read counts
/// as "not pending" (the server enforces aal2 anyway and the data would simply be empty).
final mfaPendingProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  if (ref.watch(currentUserIdProvider) == null) return false;
  try {
    return (await ref.watch(authRepositoryProvider).assuranceLevel()).mfaPending;
  } catch (_) {
    return false;
  }
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Signs out and then (when [mode] is given) switches the app mode. A session belongs to one audience
/// (ADR-12), so a mode change always closes the session first; when sign-out fails the mode is left
/// alone and the [AppException] propagates.
///
/// The notifiers are read before the first `await`: the sign-out re-runs the router redirect, which
/// can dispose the calling widget (and its `ref`) before this future completes.
Future<void> signOutAndSwitchMode(WidgetRef ref, AppMode? mode) async {
  final auth = ref.read(authRepositoryProvider);
  final modeNotifier = ref.read(appModeProvider.notifier);
  await auth.signOut();
  if (mode != null) await modeNotifier.set(mode);
}
