import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';

enum AssuranceLevel { none, aal1, aal2 }

/// Current and next authenticator assurance level of the session.
class AuthLevel {
  const AuthLevel({required this.current, required this.next});

  /// Never needs MFA (demo, or no TOTP factor).
  const AuthLevel.satisfied()
      : current = AssuranceLevel.aal1,
        next = AssuranceLevel.aal1;

  final AssuranceLevel current;
  final AssuranceLevel next;

  /// A verified TOTP factor exists but this session is still aal1.
  bool get mfaPending => next == AssuranceLevel.aal2 && current == AssuranceLevel.aal1;
}

AssuranceLevel _levelOf(AuthenticatorAssuranceLevels? l) {
  switch (l) {
    case AuthenticatorAssuranceLevels.aal2:
      return AssuranceLevel.aal2;
    case AuthenticatorAssuranceLevels.aal1:
      return AssuranceLevel.aal1;
    case null:
      return AssuranceLevel.none;
  }
}

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

  /// Current and next authenticator assurance level of the session. `next == aal2` while
  /// `current == aal1` means a verified TOTP factor exists and has not been proven in this session.
  Future<AuthLevel> assuranceLevel() => guard(() async {
        // Synchronous in gotrue 2.x (reads the session JWT); `await` keeps this compiling if it is a Future.
        // ignore: await_only_futures
        final res = await _client.auth.mfa.getAuthenticatorAssuranceLevel();
        return AuthLevel(
          current: _levelOf(res.currentLevel),
          next: _levelOf(res.nextLevel),
        );
      });

  /// Challenges the user's first verified TOTP factor with [code]; on success the session is
  /// upgraded to aal2. A wrong or expired code reads as [S.mfaInvalidCode].
  Future<void> verifyTotp(String code) => guard(() async {
        try {
          final factors = await _client.auth.mfa.listFactors();
          final totp = factors.totp.where((f) => f.status == FactorStatus.verified).toList();
          if (totp.isEmpty) throw const AppException('mfa_no_factor', S.mfaInvalidCode);
          await _client.auth.mfa.challengeAndVerify(factorId: totp.first.id, code: code.trim());
        } on AuthException catch (e) {
          final text = e.message.toLowerCase();
          final rateLimited = e.statusCode?.toString() == '429' || text.contains('rate limit') || text.contains('too many');
          if (rateLimited) rethrow;
          throw const AppException('mfa_invalid', S.mfaInvalidCode);
        }
      });

  Future<void> signOut() => guard(() async {
        await _client.auth.signOut();
      });
}
