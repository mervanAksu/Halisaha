import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/booking/presentation/booking_providers.dart';

void main() {
  test('confirmed is success', () {
    expect(decidePaymentOutcome(BookingStatus.confirmed, null), PaymentOutcome.success);
  });

  test('initiated payment keeps checking, even when the booking already expired', () {
    expect(decidePaymentOutcome(BookingStatus.pendingPayment, 'initiated'), PaymentOutcome.checking);
    expect(decidePaymentOutcome(BookingStatus.expired, 'initiated'), PaymentOutcome.checking);
  });

  test('failed payment stops polling with failure', () {
    expect(decidePaymentOutcome(BookingStatus.pendingPayment, 'failed'), PaymentOutcome.failed);
  });

  test('refund_required shows the refund outcome', () {
    expect(decidePaymentOutcome(BookingStatus.expired, 'refund_required'), PaymentOutcome.refund);
  });

  test('expired without payment is a failure; pending without payment keeps checking', () {
    expect(decidePaymentOutcome(BookingStatus.expired, null), PaymentOutcome.failed);
    expect(decidePaymentOutcome(BookingStatus.pendingPayment, null), PaymentOutcome.checking);
    expect(decidePaymentOutcome(BookingStatus.cancelled, null), PaymentOutcome.failed);
  });
}
