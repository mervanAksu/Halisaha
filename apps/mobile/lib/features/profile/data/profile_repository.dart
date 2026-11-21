import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _columns = 'id, full_name, phone, email, role, marketing_consent, kvkk_ack_at';

  Future<Profile> fetch(String userId) => guard(() async {
        final row = await _client.from('profiles').select(_columns).eq('id', userId).maybeSingle();
        if (row == null) throw AppException.fromCode('profile_not_found');
        return Profile.fromJson(row);
      });

  /// First-login step: stores the name, marketing consent and the KVKK acknowledgement time.
  Future<Profile> completeOnboarding({
    required String userId,
    required String fullName,
    required bool marketingConsent,
  }) =>
      guard(() async {
        final row = await _client
            .from('profiles')
            .update({
              'full_name': fullName.trim(),
              'marketing_consent': marketingConsent,
              'kvkk_ack_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId)
            .select(_columns)
            .single();
        return Profile.fromJson(row);
      });

  Future<Profile> updateName({required String userId, required String fullName}) => guard(() async {
        final row = await _client
            .from('profiles')
            .update({'full_name': fullName.trim()})
            .eq('id', userId)
            .select(_columns)
            .single();
        return Profile.fromJson(row);
      });

  /// Calls the `delete-account` edge function, then drops the local session.
  Future<void> deleteAccount() => guard(() async {
        await _client.functions.invoke('delete-account', body: <String, dynamic>{});
        try {
          await _client.auth.signOut(scope: SignOutScope.local);
        } on Exception {
          // The auth user is already gone server-side; the local session is cleared by the SDK anyway.
        }
      });
}
