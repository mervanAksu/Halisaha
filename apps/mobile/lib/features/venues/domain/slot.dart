import '../../../core/utils/json_utils.dart';

enum SlotState {
  available,
  booked,
  past;

  /// Unknown values are treated as booked so they can never be selected.
  static SlotState fromWire(String value) {
    switch (value) {
      case 'available':
        return SlotState.available;
      case 'past':
        return SlotState.past;
      default:
        return SlotState.booked;
    }
  }
}

/// One row of `get_availability`.
class Slot {
  const Slot({
    required this.startsAt,
    required this.endsAt,
    required this.state,
    required this.priceKurus,
    required this.depositKurus,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      startsAt: parseUtc(json['starts_at']),
      endsAt: parseUtc(json['ends_at']),
      state: SlotState.fromWire(json['state'] as String),
      priceKurus: asInt(json['price_kurus']),
      depositKurus: asInt(json['deposit_kurus']),
    );
  }

  final DateTime startsAt;
  final DateTime endsAt;
  final SlotState state;
  final int priceKurus;
  final int depositKurus;

  bool get isAvailable => state == SlotState.available;
}
