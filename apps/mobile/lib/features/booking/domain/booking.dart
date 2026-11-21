import '../../../core/utils/json_utils.dart';

enum BookingStatus {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  cancelled('cancelled'),
  expired('expired'),
  completed('completed'),
  noShow('no_show');

  const BookingStatus(this.wire);

  final String wire;

  static BookingStatus fromWire(String value) {
    for (final s in BookingStatus.values) {
      if (s.wire == value) return s;
    }
    throw FormatException('Unknown booking status: $value');
  }
}

/// What the cancel confirmation dialog tells the user in advance.
enum RefundPreview {
  /// Unpaid hold: nothing was charged.
  notCharged,

  /// The pitch has no deposit: nothing to refund.
  noDeposit,

  /// Outside the cancellation window: deposit is refunded.
  refundable,

  /// Inside the cancellation window: deposit is forfeited.
  forfeited,
}

/// Window used when the venue join is missing (matches the column default).
const int defaultCancellationWindowHours = 24;

/// A row of `bookings`, optionally joined with `pitches(name, format)` and
/// `venues(name, district, address, lat, lng, cancellation_window_hours)`.
class Booking {
  const Booking({
    required this.id,
    required this.pitchId,
    required this.venueId,
    required this.source,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.priceKurus,
    required this.depositKurus,
    required this.commissionKurus,
    this.userId,
    this.holdExpiresAt,
    this.cancelledAt,
    this.pitchName,
    this.pitchFormat,
    this.venueName,
    this.venueDistrict,
    this.venueAddress,
    this.venueLat,
    this.venueLng,
    this.cancellationWindowHours,
    this.customerName,
    this.customerPhone,
    this.note,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final pitch = json['pitches'];
    final venue = json['venues'];
    return Booking(
      id: json['id'] as String,
      pitchId: json['pitch_id'] as String,
      venueId: json['venue_id'] as String,
      userId: json['user_id'] as String?,
      source: (json['source'] as String?) ?? 'app',
      status: BookingStatus.fromWire(json['status'] as String),
      startsAt: parseUtc(json['starts_at']),
      endsAt: parseUtc(json['ends_at']),
      priceKurus: asInt(json['price_kurus']),
      depositKurus: asInt(json['deposit_kurus']),
      commissionKurus: asIntOrNull(json['commission_kurus']) ?? 0,
      holdExpiresAt: parseUtcOrNull(json['hold_expires_at']),
      cancelledAt: parseUtcOrNull(json['cancelled_at']),
      pitchName: pitch is Map ? pitch['name'] as String? : null,
      pitchFormat: pitch is Map ? pitch['format'] as String? : null,
      venueName: venue is Map ? venue['name'] as String? : null,
      venueDistrict: venue is Map ? venue['district'] as String? : null,
      venueAddress: venue is Map ? venue['address'] as String? : null,
      venueLat: venue is Map ? asDoubleOrNull(venue['lat']) : null,
      venueLng: venue is Map ? asDoubleOrNull(venue['lng']) : null,
      cancellationWindowHours: venue is Map ? asIntOrNull(venue['cancellation_window_hours']) : null,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      note: json['note'] as String?,
    );
  }

  final String id;
  final String pitchId;
  final String venueId;
  final String? userId;
  final String source;
  final BookingStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priceKurus;
  final int depositKurus;
  final int commissionKurus;
  final DateTime? holdExpiresAt;
  final DateTime? cancelledAt;
  final String? pitchName;
  final String? pitchFormat;
  final String? venueName;
  final String? venueDistrict;
  final String? venueAddress;
  final double? venueLat;
  final double? venueLng;
  final int? cancellationWindowHours;

  /// Manual (phone) bookings only.
  final String? customerName;
  final String? customerPhone;
  final String? note;

  Booking copyWith({BookingStatus? status, DateTime? cancelledAt}) {
    return Booking(
      id: id,
      pitchId: pitchId,
      venueId: venueId,
      userId: userId,
      source: source,
      status: status ?? this.status,
      startsAt: startsAt,
      endsAt: endsAt,
      priceKurus: priceKurus,
      depositKurus: depositKurus,
      commissionKurus: commissionKurus,
      holdExpiresAt: holdExpiresAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      pitchName: pitchName,
      pitchFormat: pitchFormat,
      venueName: venueName,
      venueDistrict: venueDistrict,
      venueAddress: venueAddress,
      venueLat: venueLat,
      venueLng: venueLng,
      cancellationWindowHours: cancellationWindowHours,
      customerName: customerName,
      customerPhone: customerPhone,
      note: note,
    );
  }

  /// Amount paid at the venue.
  int get remainderKurus => priceKurus - depositKurus;

  /// Status as the user should see it: an unpaid hold past its deadline is
  /// shown as expired even before the cron job flips the row.
  BookingStatus displayStatus(DateTime now) {
    if (status == BookingStatus.pendingPayment && holdExpiresAt != null && !holdExpiresAt!.isAfter(now)) {
      return BookingStatus.expired;
    }
    return status;
  }

  /// "Gelecek" tab: live booking that has not ended yet.
  bool isUpcoming(DateTime now) {
    final s = displayStatus(now);
    return (s == BookingStatus.pendingPayment || s == BookingStatus.confirmed) && endsAt.isAfter(now);
  }

  bool canCancel(DateTime now) {
    final s = displayStatus(now);
    if (s == BookingStatus.pendingPayment) return true;
    return s == BookingStatus.confirmed && startsAt.isAfter(now);
  }

  /// Mirrors `cancel_booking`: refund when `starts_at - now >= window`.
  RefundPreview refundPreview(DateTime now) {
    if (status == BookingStatus.pendingPayment) return RefundPreview.notCharged;
    if (depositKurus == 0) return RefundPreview.noDeposit;
    final window = Duration(hours: cancellationWindowHours ?? defaultCancellationWindowHours);
    return startsAt.difference(now) >= window ? RefundPreview.refundable : RefundPreview.forfeited;
  }
}
