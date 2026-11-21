import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/booking.dart';
import '../domain/cancel_result.dart';
import '../domain/payment_session.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  static const String _select = '*, pitches(name, format), venues(name, district, address, lat, lng, cancellation_window_hours)';

  /// RPC `create_booking_hold`. Returns `confirmed` immediately when the deposit is 0.
  Future<Booking> createHold({required String pitchId, required DateTime startsAt}) => guard(() async {
        final response = await _client.rpc('create_booking_hold', params: {
          'p_pitch_id': pitchId,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
        });
        return Booking.fromJson(asRow(response));
      });

  /// Edge function `paytr-create-payment`.
  Future<PaymentSession> startPayment(String bookingId) => guard(() async {
        final response = await _client.functions.invoke('paytr-create-payment', body: {'booking_id': bookingId});
        final data = response.data;
        if (data is! Map || data['iframe_url'] is! String) {
          throw AppException.fromCode('payment_provider_error');
        }
        return PaymentSession.fromJson(Map<String, dynamic>.from(data));
      });

  /// The single source of truth for payment results (never trust WebView redirects).
  Future<Booking> fetchBooking(String bookingId) => guard(() async {
        final row = await _client.from('bookings').select(_select).eq('id', bookingId).maybeSingle();
        if (row == null) throw AppException.fromCode('booking_not_found');
        return Booking.fromJson(row);
      });

  /// Own bookings, newest first. The explicit `user_id` filter keeps an owner account
  /// (who can read its venues' bookings through RLS) from seeing them in "Maçlarım".
  Future<List<Booking>> fetchMyBookings() => guard(() async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) throw AppException.fromCode('not_authenticated');
        final response = await _client
            .from('bookings')
            .select(_select)
            .eq('user_id', uid)
            .order('starts_at', ascending: false)
            .limit(200);
        return asRows(response).map(Booking.fromJson).toList();
      });

  /// RPC `cancel_booking` (returns a one-row table `{status, refund_eligible}`).
  Future<CancelResult> cancel(String bookingId, {String? reason}) => guard(() async {
        final params = <String, dynamic>{'p_booking_id': bookingId};
        if (reason != null) params['p_reason'] = reason;
        final response = await _client.rpc('cancel_booking', params: params);
        return CancelResult.fromJson(asRow(response));
      });

  /// Status of the newest payment attempt of a booking (`initiated`, `succeeded`, `failed`,
  /// `refund_required`, `refunded`), or null when none exists. RLS: own rows only.
  Future<String?> fetchLatestPaymentStatus(String bookingId) => guard(() async {
        final response = await _client
            .from('payments')
            .select('status')
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false)
            .limit(1);
        final rows = asRows(response);
        return rows.isEmpty ? null : rows.first['status'] as String?;
      });
}
