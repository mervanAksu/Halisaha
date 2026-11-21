import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/utils/urls.dart';

void main() {
  group('isSafeExternalUrl', () {
    test('accepts https, tel and mailto links the app builds', () {
      expect(isSafeExternalUrl('https://www.google.com/maps/search/?api=1&query=41.0,28.5'), isTrue);
      expect(isSafeExternalUrl('https://wa.me/905551112233'), isTrue);
      expect(isSafeExternalUrl('tel:+902120000000'), isTrue);
      expect(isSafeExternalUrl('mailto:destek@example.com'), isTrue);
      expect(isSafeExternalUrl(mapsUrl(lat: 41.0206, lng: 28.5785, query: 'x')), isTrue);
      expect(isSafeExternalUrl(mapsUrl(query: 'Mavi Çim Spor')), isTrue);
    });

    test('refuses everything else, which is what a hostile server string would look like', () {
      expect(isSafeExternalUrl('http://example.com'), isFalse);
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl('intent://x#Intent;scheme=a;end'), isFalse);
      expect(isSafeExternalUrl('whatsapp://send?phone=1'), isFalse);
      expect(isSafeExternalUrl('sms:+905550000000'), isFalse);
      expect(isSafeExternalUrl('market://details?id=x'), isFalse);
      expect(isSafeExternalUrl('https://'), isFalse);
      expect(isSafeExternalUrl('example.com'), isFalse);
      expect(isSafeExternalUrl(''), isFalse);
    });
  });

  group('telUrl', () {
    test('keeps digits and a leading plus only', () {
      expect(telUrl('+90 (212) 000 01 01'), 'tel:+902120000101');
      expect(telUrl('0212 000 01 01'), 'tel:02120000101');
    });

    test('rejects missing or implausible numbers', () {
      expect(telUrl(null), isNull);
      expect(telUrl(''), isNull);
      expect(telUrl('abc'), isNull);
      expect(telUrl('123'), isNull);
      expect(telUrl('1234567890123456'), isNull);
    });
  });
}
