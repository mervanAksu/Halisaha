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

enum PaymentOutcome { checking, success, failed, refund }

/// One poll result of the payment result screen.
class PaymentPoll {
  const PaymentPoll({this.booking, this.error, this.outcome = PaymentOutcome.checking, this.timedOut = false});

  final Booking? booking;
  final Object? error;
  final PaymentOutcome outcome;
  final bool timedOut;

  bool get isDecided => outcome != PaymentOutcome.checking;
}

const Duration paymentPollInterval = Duration(seconds: 2);
const Duration paymentPollTimeout = Duration(minutes: 2);

/// Decides the outcome from backend state only (booking status, then the latest payment row
/// while the booking is still pending or expired). WebView redirects are never trusted.
PaymentOutcome decidePaymentOutcome(BookingStatus status, String? latestPaymentStatus) {
  switch (status) {
    case BookingStatus.confirmed:
    case BookingStatus.completed:
    case BookingStatus.noShow:
      return PaymentOutcome.success;
    case BookingStatus.cancelled:
      return PaymentOutcome.failed;
    case BookingStatus.pendingPayment:
    case BookingStatus.expired:
      switch (latestPaymentStatus) {
        case 'refund_required':
        case 'refunded':
          return PaymentOutcome.refund;
        case 'failed':
          return PaymentOutcome.failed;
        case 'initiated':
        case 'succeeded':
          return PaymentOutcome.checking; // callback still on its way
        default:
          return status == BookingStatus.expired ? PaymentOutcome.failed : PaymentOutcome.checking;
      }
  }
}

/// Polls the booking row every 2 s for up to 2 min.
final paymentPollProvider = StreamProvider.autoDispose.family<PaymentPoll, String>((ref, bookingId) async* {
  final repo = ref.watch(bookingRepositoryProvider);
  final deadline = DateTime.now().add(paymentPollTimeout);
  while (true) {
    Booking? booking;
    Object? error;
    var outcome = PaymentOutcome.checking;
    try {
      booking = await repo.fetchBooking(bookingId);
      String? paymentStatus;
      if (booking.status == BookingStatus.pendingPayment || booking.status == BookingStatus.expired) {
        paymentStatus = await repo.fetchLatestPaymentStatus(bookingId);
      }
      outcome = decidePaymentOutcome(booking.status, paymentStatus);
    } catch (e) {
      error = e;
    }
    final decided = outcome != PaymentOutcome.checking;
    final timedOut = !decided && DateTime.now().isAfter(deadline);
    yield PaymentPoll(booking: booking, error: error, outcome: outcome, timedOut: timedOut);
    if (decided || timedOut) return;
    await Future<void>.delayed(paymentPollInterval);
  }
});
