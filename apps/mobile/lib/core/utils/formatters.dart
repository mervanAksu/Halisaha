import 'package:intl/intl.dart';

/// Formats an integer amount of kuruş as Turkish lira: 350000 -> "3.500 ₺",
/// 350050 -> "3.500,50 ₺". Money is never handled as a double.
String formatTry(int kurus) {
  final negative = kurus < 0;
  final abs = kurus.abs();
  final lira = abs ~/ 100;
  final rest = abs % 100;
  final digits = lira.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  final decimals = rest == 0 ? '' : ',${rest.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$buffer$decimals ₺';
}

/// Turkey is fixed at UTC+3 with no daylight saving time (since 2016), which is
/// exactly what `Europe/Istanbul` resolves to. Hence a constant offset is a
/// correct conversion and avoids a timezone database dependency.
const Duration istanbulOffset = Duration(hours: 3);

/// Converts any instant to Istanbul wall-clock time.
///
/// The returned value is flagged `isUtc` only so that no further local-zone
/// conversion happens; its fields (hour, day, ...) are the Istanbul wall clock.
/// Use it only for display / date arithmetic, never to send back to the server.
DateTime toIstanbul(DateTime instant) => instant.toUtc().add(istanbulOffset);

extension IstanbulDateTime on DateTime {
  /// See [toIstanbul].
  DateTime toIstanbul() => toUtc().add(istanbulOffset);
}

/// Midnight of today's Istanbul calendar date (as a wall-clock value, see [toIstanbul]).
DateTime istanbulToday([DateTime? now]) {
  final n = toIstanbul(now ?? DateTime.now());
  return DateTime.utc(n.year, n.month, n.day);
}

/// `yyyy-MM-dd` for the RPC `p_date` parameter.
String formatIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Inverse of [formatIsoDate]: `yyyy-MM-dd` -> midnight of that date as a wall-clock value (UTC-flagged).
DateTime parseIsoDate(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

const String _locale = 'tr_TR';

/// "20:00"
String formatIstanbulTime(DateTime instant) => DateFormat('HH:mm').format(toIstanbul(instant));

/// "6 Aralık 2026" (needs `initializeDateFormatting('tr_TR')` once at startup).
String formatIstanbulDate(DateTime instant) => DateFormat('d MMMM yyyy', _locale).format(toIstanbul(instant));

/// "6 Aralık 2026, Pazar" 
String formatIstanbulDateWithWeekday(DateTime instant) =>
    DateFormat('d MMMM yyyy, EEEE', _locale).format(toIstanbul(instant));

/// Weekday name of an Istanbul calendar date, e.g. "Pazartesi". [wallClockDate] is already an Istanbul date.
String formatWeekdayLong(DateTime wallClockDate) => DateFormat('EEEE', _locale).format(wallClockDate);

/// "6 Aralık 2026, 20:00"
String formatIstanbulDateTime(DateTime instant) => '${formatIstanbulDate(instant)}, ${formatIstanbulTime(instant)}';

/// "20:00 – 21:00"
String formatTimeRange(DateTime start, DateTime end) => '${formatIstanbulTime(start)} – ${formatIstanbulTime(end)}';

/// Short weekday for a date-strip cell, e.g. "Pzt". [wallClockDate] is already an Istanbul date.
String formatWeekdayShort(DateTime wallClockDate) => DateFormat('EEE', _locale).format(wallClockDate);

/// Short month for a date-strip cell, e.g. "Ara".
String formatMonthShort(DateTime wallClockDate) => DateFormat('MMM', _locale).format(wallClockDate);

/// "09:41" countdown label.
String formatCountdown(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// "2,3 km" or "850 m".
String formatDistanceKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}
