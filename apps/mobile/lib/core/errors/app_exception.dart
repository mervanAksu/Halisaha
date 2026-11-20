import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/strings.dart';

/// Every error code listed in docs/API_CONTRACT.md that the mobile app can see.
const List<String> knownErrorCodes = <String>[
  'not_authenticated',
  'pitch_not_found',
  'slot_in_past',
  'too_far_ahead',
  'outside_opening_hours',
  'too_many_pending_holds',
  'slot_taken',
  'hold_expired',
  'booking_not_found',
  'not_cancellable',
  'forbidden',
  'invalid_range',
  'invalid_status',
  'invalid_source',
  'payment_provider_error',
  'owner_account',
  'venue_not_found',
  'payment_not_found',
  'too_many_recent_holds',
  'too_many_active_bookings',
  'too_many_payment_attempts',
  'slot_started',
];

/// Turkish user message for a contract error code (API_CONTRACT "Hata kodları").
String messageForCode(String code) {
  switch (code) {
    case 'not_authenticated':
      return S.errNotAuthenticated;
    case 'pitch_not_found':
      return S.errPitchNotFound;
    case 'slot_in_past':
      return S.errSlotInPast;
    case 'too_far_ahead':
      return S.errTooFarAhead;
    case 'outside_opening_hours':
      return S.errOutsideOpeningHours;
    case 'too_many_pending_holds':
      return S.errTooManyPendingHolds;
    case 'slot_taken':
      return S.errSlotTaken;
    case 'hold_expired':
      return S.errHoldExpired;
    case 'booking_not_found':
      return S.errBookingNotFound;
    case 'not_cancellable':
      return S.errNotCancellable;
    case 'forbidden':
      return S.errForbidden;
    case 'invalid_range':
    case 'invalid_status':
    case 'invalid_source':
      return S.errInvalidRequest;
    case 'payment_provider_error':
      return S.errPaymentProvider;
    case 'network':
      return S.errNetwork;
    case 'venue_not_found':
      return S.errVenueNotFound;
    case 'owner_account':
      return S.errOwnerAccount;
    case 'payment_not_found':
      return S.errPaymentNotFound;
    case 'too_many_recent_holds':
      return S.errTooManyRecentHolds;
    case 'too_many_active_bookings':
      return S.errTooManyActiveBookings;
    case 'too_many_payment_attempts':
      return S.errTooManyPaymentAttempts;
    case 'slot_started':
      return S.errSlotStarted;
    case 'profile_not_found':
      return S.errProfileMissing;
    default:
      return S.errGeneric;
  }
}

/// Finds a known contract code inside server text such as `slot_taken` or `ERROR: slot_taken`.
String? extractErrorCode(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (knownErrorCodes.contains(trimmed)) return trimmed;
  for (final code in knownErrorCodes) {
    if (trimmed.contains(code)) return code;
  }
  return null;
}

/// App-level error carrying a stable [code] and a Turkish [message] fit for display.
class AppException implements Exception {
  const AppException(this.code, this.message);

  /// Builds the exception for a code; unknown codes get the generic message.
  factory AppException.fromCode(String code) => AppException(code, messageForCode(code));

  /// Converts anything thrown by Supabase / the network into an [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    if (error is PostgrestException) {
      final code = extractErrorCode(error.message) ?? extractErrorCode(error.details?.toString());
      if (code != null) return AppException.fromCode(code);
      return const AppException('unknown', S.errGeneric);
    }

    if (error is FunctionException) {
      final details = error.details;
      String? text;
      if (details is Map) {
        text = details['error']?.toString();
      } else if (details is String) {
        text = details;
      }
      final code = extractErrorCode(text);
      if (code != null) return AppException.fromCode(code);
      if (error.status == 401) return AppException.fromCode('not_authenticated');
      return const AppException('unknown', S.errGeneric);
    }

    if (error is AuthException) {
      final text = error.message.toLowerCase();
      if (error.statusCode?.toString() == '429' || text.contains('rate limit') || text.contains('too many')) {
        return const AppException('rate_limited', S.errTooManyRequests);
      }
      if (text.contains('expired') || text.contains('invalid')) {
        return const AppException('otp_invalid', S.errOtpInvalid);
      }
      return const AppException('auth_error', S.errAuthGeneric);
    }

    if (error is SocketException || error is TimeoutException) {
      return AppException.fromCode('network');
    }
    final typeName = error.runtimeType.toString();
    if (typeName.contains('ClientException') || typeName.contains('SocketException')) {
      return AppException.fromCode('network');
    }
    return const AppException('unknown', S.errGeneric);
  }

  final String code;
  final String message;

  @override
  String toString() => 'AppException($code): $message';
}

/// Runs [action] and rethrows any `Exception` as an [AppException].
/// Programming errors (`Error`) are deliberately not swallowed.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on Exception catch (e) {
    throw AppException.from(e);
  }
}
