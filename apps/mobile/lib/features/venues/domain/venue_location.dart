import '../../../core/utils/json_utils.dart';
import '../../../core/utils/turkish.dart';

/// One row of `list_venue_locations`: a city / district pair that has venues.
class VenueLocation {
  const VenueLocation({required this.city, required this.district, required this.venueCount});

  factory VenueLocation.fromJson(Map<String, dynamic> json) {
    return VenueLocation(
      city: (json['city'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      venueCount: asIntOrNull(json['venue_count']) ?? 0,
    );
  }

  final String city;
  final String district;
  final int venueCount;
}

/// A province with the total number of venues in it.
class CityOption {
  const CityOption({required this.city, required this.venueCount});

  final String city;
  final int venueCount;
}

/// A district of one province with its venue count.
class DistrictOption {
  const DistrictOption({required this.district, required this.venueCount});

  final String district;
  final int venueCount;
}

/// Unique provinces (Turkish alphabetical order) with summed venue counts.
List<CityOption> cityOptions(List<VenueLocation> locations) {
  final counts = <String, int>{};
  for (final l in locations) {
    if (l.city.isEmpty) continue;
    counts.update(l.city, (n) => n + l.venueCount, ifAbsent: () => l.venueCount);
  }
  final result = [for (final e in counts.entries) CityOption(city: e.key, venueCount: e.value)]
    ..sort((a, b) => compareTr(a.city, b.city));
  return result;
}

/// Districts of [city] (Turkish alphabetical order).
List<DistrictOption> districtOptions(List<VenueLocation> locations, String city) {
  final counts = <String, int>{};
  for (final l in locations) {
    if (l.city != city || l.district.isEmpty) continue;
    counts.update(l.district, (n) => n + l.venueCount, ifAbsent: () => l.venueCount);
  }
  final result = [for (final e in counts.entries) DistrictOption(district: e.key, venueCount: e.value)]
    ..sort((a, b) => compareTr(a.district, b.district));
  return result;
}
