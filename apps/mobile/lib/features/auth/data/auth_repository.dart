import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';

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

  /// E-mail + password sign-in for owner accounts (same account as the web panel, ADR-12).
  /// Every failure except rate limiting / network reads as the same generic message so the form
  /// never reveals whether an e-mail exists.
  Future<void> signInWithPassword({required String email, required String password}) => guard(() async {
        try {
          // TODO(BASELINE S-05): pass captchaToken here once captcha is enabled, same as the OTP path.
          await _client.auth.signInWithPassword(email: email.trim(), password: password);
        } on AuthException catch (e) {
          final text = e.message.toLowerCase();
          final rateLimited = e.statusCode?.toString() == '429' || text.contains('rate limit') || text.contains('too many');
          if (rateLimited) rethrow;
          throw const AppException('invalid_credentials', S.ownerLoginInvalid);
        }
      });

  Future<void> signOut() => guard(() async {
        await _client.auth.signOut();
      });
}
