import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's profile; `null` data means signed out.
class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.read(profileRepositoryProvider).fetch(userId);
  }

  String _requireUserId() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw AppException.fromCode('not_authenticated');
    return userId;
  }

  Future<void> completeOnboarding({required String fullName, required bool marketingConsent}) async {
    final updated = await ref.read(profileRepositoryProvider).completeOnboarding(
          userId: _requireUserId(),
          fullName: fullName,
          marketingConsent: marketingConsent,
        );
    state = AsyncData<Profile?>(updated);
  }

  /// Replaces the cached profile (used by the demo to flip the role without a backend).
  void replace(Profile profile) => state = AsyncData<Profile?>(profile);

  Future<void> updateName(String fullName) async {
    final updated = await ref.read(profileRepositoryProvider).updateName(
          userId: _requireUserId(),
          fullName: fullName,
        );
    state = AsyncData<Profile?>(updated);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);
