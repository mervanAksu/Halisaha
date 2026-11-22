import 'dart:convert';

import '../../../core/l10n/strings.dart';

/// The home screen's location filter: nothing selected, a whole province, or some districts of it.
class LocationFilter {
  const LocationFilter({this.city, this.districts = const <String>{}});

  /// No filter ("Tüm Türkiye").
  static const LocationFilter none = LocationFilter();

  /// Province name, or null for all of Turkey.
  final String? city;

  /// Selected districts of [city]; empty = the whole province.
  final Set<String> districts;

  bool get isActive => city != null;

  /// "Tüm Türkiye", "İstanbul", "İstanbul · Kadıköy" or "İstanbul · 3 ilçe".
  String get label {
    final c = city;
    if (c == null) return S.locationAll;
    if (districts.isEmpty) return c;
    if (districts.length == 1) return '$c · ${districts.first}';
    return '$c · ${S.districtCount(districts.length)}';
  }

  /// Sorted copy for RPC parameters; null when no district is selected.
  List<String>? get districtsParam => districts.isEmpty ? null : (districts.toList()..sort());

  String toJsonString() => jsonEncode({'city': city, 'districts': districts.toList()..sort()});

  /// Never throws: anything unreadable yields [none].
  static LocationFilter fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return none;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return none;
      final city = decoded['city'];
      if (city is! String || city.isEmpty) return none;
      final rawDistricts = decoded['districts'];
      final districts = rawDistricts is List ? rawDistricts.whereType<String>().toSet() : <String>{};
      return LocationFilter(city: city, districts: districts);
    } catch (_) {
      return none;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LocationFilter &&
      other.city == city &&
      other.districts.length == districts.length &&
      other.districts.containsAll(districts);

  @override
  int get hashCode => Object.hash(city, Object.hashAllUnordered(districts));
}
