import '../../../core/utils/json_utils.dart';

/// One row of `list_venues`.
class VenueSummary {
  const VenueSummary({
    required this.id,
    required this.name,
    required this.district,
    this.city = '',
    required this.address,
    this.coverPhotoPath,
    this.minHourlyPriceKurus,
    this.openTime,
    this.closeTime,
    this.distanceKm,
    this.isFavorite = false,
  });

  factory VenueSummary.fromJson(Map<String, dynamic> json) {
    return VenueSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      city: (json['city'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      coverPhotoPath: json['cover_photo_path'] as String?,
      minHourlyPriceKurus: asIntOrNull(json['min_hourly_price_kurus']),
      openTime: parseHourMinute(json['open_time']),
      closeTime: parseHourMinute(json['close_time']),
      distanceKm: asDoubleOrNull(json['distance_km']),
      isFavorite: (json['is_favorite'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final String? coverPhotoPath;
  final int? minHourlyPriceKurus;

  /// Today's opening hours as "HH:mm"; null means closed today.
  final String? openTime;
  final String? closeTime;
  final double? distanceKm;
  final bool isFavorite;

  bool get isOpenToday => openTime != null && closeTime != null;
}
