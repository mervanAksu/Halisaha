import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/utils/formatters.dart';
import 'package:halisaha/core/utils/json_utils.dart';
import 'package:halisaha/core/utils/phone.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('formatTry', () {
    test('formats whole lira amounts with thousands separator', () {
      expect(formatTry(350000), '3.500 ₺');
      expect(formatTry(100), '1 ₺');
      expect(formatTry(0), '0 ₺');
      expect(formatTry(99900), '999 ₺');
      expect(formatTry(100000), '1.000 ₺');
    });

    test('shows kuruş only when non-zero', () {
      expect(formatTry(350050), '3.500,50 ₺');
      expect(formatTry(99), '0,99 ₺');
      expect(formatTry(105), '1,05 ₺');
    });

    test('groups large values and handles negatives', () {
      expect(formatTry(123456789), '1.234.567,89 ₺');
      expect(formatTry(100000000), '1.000.000 ₺');
      expect(formatTry(-250000), '-2.500 ₺');
    });
  });

  group('Istanbul time (UTC+3, no DST)', () {
    test('converts UTC to Istanbul wall clock', () {
      final utc = DateTime.utc(2026, 12, 6, 17, 0);
      expect(utc.toIstanbul().hour, 20);
      expect(toIstanbul(utc).hour, 20);
      expect(formatIstanbulTime(utc), '20:00');
    });

    test('rolls over midnight into the next day', () {
      final utc = DateTime.utc(2026, 12, 6, 21, 30);
      final ist = toIstanbul(utc);
      expect(ist.day, 7);
      expect(ist.hour, 0);
      expect(ist.minute, 30);
      expect(formatIstanbulDate(utc), '7 Aralık 2026');
    });

    test('has no summer-time shift', () {
      final summer = DateTime.utc(2026, 7, 1, 12, 0);
      expect(formatIstanbulTime(summer), '15:00');
    });

    test('formats date-time and ranges', () {
      final start = DateTime.utc(2026, 12, 6, 17, 0);
      final end = DateTime.utc(2026, 12, 6, 18, 0);
      expect(formatIstanbulDateTime(start), '6 Aralık 2026, 20:00');
      expect(formatTimeRange(start, end), '20:00 – 21:00');
    });

    test('istanbulToday uses the Istanbul calendar date', () {
      // 22:30 UTC on Dec 6 is already Dec 7 in Istanbul.
      final today = istanbulToday(DateTime.utc(2026, 12, 6, 22, 30));
      expect(today, DateTime.utc(2026, 12, 7));
    });

    test('formatIsoDate pads fields', () {
      expect(formatIsoDate(DateTime.utc(2026, 1, 5)), '2026-01-05');
    });
  });

  group('misc formatting', () {
    test('countdown', () {
      expect(formatCountdown(const Duration(minutes: 9, seconds: 41)), '09:41');
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });

    test('distance', () {
      expect(formatDistanceKm(0.85), '850 m');
      expect(formatDistanceKm(2.34), '2,3 km');
    });

    test('parseHourMinute drops seconds', () {
      expect(parseHourMinute('18:00:00'), '18:00');
      expect(parseHourMinute(null), isNull);
    });
  });

  group('phone', () {
    test('normalises accepted inputs', () {
      expect(normalizeTrPhoneInput('555 123 45 67'), '5551234567');
      expect(normalizeTrPhoneInput('05551234567'), '5551234567');
      expect(normalizeTrPhoneInput('+90 555 123 45 67'), '5551234567');
    });

    test('rejects invalid inputs', () {
      expect(normalizeTrPhoneInput('123'), isNull);
      expect(normalizeTrPhoneInput('4551234567'), isNull);
      expect(normalizeTrPhoneInput(''), isNull);
    });

    test('E.164 and display', () {
      expect(toE164Tr('5551234567'), '+905551234567');
      expect(formatPhoneDisplay('905551234567'), '+90 555 123 45 67');
    });
  });
}
