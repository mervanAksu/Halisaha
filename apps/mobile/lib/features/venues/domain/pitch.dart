import '../../../core/utils/json_utils.dart';

class Pitch {
  const Pitch({
    required this.id,
    required this.name,
    required this.format,
    required this.isIndoor,
    required this.hourlyPriceKurus,
    required this.depositKurus,
    required this.slotMinutes,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Pitch.fromJson(Map<String, dynamic> json) {
    return Pitch(
      id: json['id'] as String,
      name: json['name'] as String,
      format: (json['format'] as String?) ?? '',
      isIndoor: (json['is_indoor'] as bool?) ?? true,
      hourlyPriceKurus: asInt(json['hourly_price_kurus']),
      depositKurus: asInt(json['deposit_kurus']),
      slotMinutes: asIntOrNull(json['slot_minutes']) ?? 60,
      sortOrder: asIntOrNull(json['sort_order']) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  final String id;
  final String name;
  final String format;
  final bool isIndoor;
  final int hourlyPriceKurus;
  final int depositKurus;
  final int slotMinutes;
  final int sortOrder;
  final bool isActive;
}
