import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sends the SMS code. [e164Phone] looks like "+905551234567".
  Future<void> sendOtp(String e164Phone) => guard(() async {
        await _client.auth.signInWithOtp(phone: e164Phone);
      });

  Future<void> verifyOtp({required String e164Phone, required String code}) => guard(() async {
        await _client.auth.verifyOTP(phone: e164Phone, token: code, type: OtpType.sms);
      });

  Future<void> signOut() => guard(() async {
        await _client.auth.signOut();
      });
}
