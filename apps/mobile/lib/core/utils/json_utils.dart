/// Small helpers for hand-written `fromJson` constructors.
DateTime parseUtc(Object? value) => DateTime.parse(value! as String).toUtc();

DateTime? parseUtcOrNull(Object? value) => value == null ? null : DateTime.parse(value as String).toUtc();

int asInt(Object? value) => (value! as num).toInt();

int? asIntOrNull(Object? value) => value == null ? null : (value as num).toInt();

double? asDoubleOrNull(Object? value) => value == null ? null : (value as num).toDouble();

/// "18:00:00" -> "18:00". Postgres `time` columns arrive with seconds.
String? parseHourMinute(Object? value) {
  if (value == null) return null;
  final s = value as String;
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// PostgREST returns a single composite as an object, but tolerate a one-row list too.
Map<String, dynamic> asRow(Object? response) {
  if (response is List) {
    if (response.isEmpty) throw const FormatException('Empty response');
    return Map<String, dynamic>.from(response.first as Map);
  }
  return Map<String, dynamic>.from(response! as Map);
}

List<Map<String, dynamic>> asRows(Object? response) {
  if (response == null) return const [];
  return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
