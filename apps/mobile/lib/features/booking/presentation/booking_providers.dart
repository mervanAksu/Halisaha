import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});

/// All own bookings; "Gelecek" / "Geçmiş" are split on the client.
final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).fetchMyBookings();
});

/// One poll result of the payment result screen.
class PaymentPoll {
  const PaymentPoll({this.booking, this.error, this.timedOut = false});

  final Booking? booking;
  final Object? error;
  final bool timedOut;

  bool get isDecided => booking != null && booking!.status != BookingStatus.pendingPayment;
}

const Duration paymentPollInterval = Duration(seconds: 2);
const Duration paymentPollTimeout = Duration(minutes: 2);

/// Polls the booking row every 2 s for up to 2 min. The payment outcome is decided
/// only by the backend status, never by WebView redirects.
final paymentPollProvider = StreamProvider.autoDispose.family<PaymentPoll, String>((ref, bookingId) async* {
  final repo = ref.watch(bookingRepositoryProvider);
  final deadline = DateTime.now().add(paymentPollTimeout);
  while (true) {
    Booking? booking;
    Object? error;
    try {
      booking = await repo.fetchBooking(bookingId);
    } catch (e) {
      error = e;
    }
    final decided = booking != null && booking.status != BookingStatus.pendingPayment;
    final timedOut = !decided && DateTime.now().isAfter(deadline);
    yield PaymentPoll(booking: booking, error: error, timedOut: timedOut);
    if (decided || timedOut) return;
    await Future<void>.delayed(paymentPollInterval);
  }
});
