import '../../venues/domain/slot.dart';

/// Selection handed from venue detail to the booking summary screen.
class BookingDraft {
  const BookingDraft({
    required this.venueId,
    required this.venueName,
    required this.district,
    required this.cancellationWindowHours,
    required this.pitchId,
    required this.pitchName,
    required this.pitchFormat,
    required this.slot,
  });

  final String venueId;
  final String venueName;
  final String district;
  final int cancellationWindowHours;
  final String pitchId;
  final String pitchName;
  final String pitchFormat;
  final Slot slot;
}
