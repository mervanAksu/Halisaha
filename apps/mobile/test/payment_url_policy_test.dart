import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/features/booking/domain/payment_url_policy.dart';

void main() {
  const resultBase = 'https://app.example.com/payment/result';

  PaymentNavigation main(String url, {String base = resultBase}) =>
      decidePaymentNavigation(url, isMainFrame: true, resultBaseUrl: base);

  PaymentNavigation frame(String url, {String base = resultBase}) =>
      decidePaymentNavigation(url, isMainFrame: false, resultBaseUrl: base);

  group('main frame', () {
    test('allows https on paytr.com and its subdomains', () {
      expect(main('https://www.paytr.com/odeme/guvenli/abc123'), PaymentNavigation.allow);
      expect(main('https://iframe.paytr.com/x'), PaymentNavigation.allow);
      expect(main('https://paytr.com/'), PaymentNavigation.allow);
      expect(main('https://WWW.PAYTR.COM/x'), PaymentNavigation.allow);
    });

    test('blocks look-alike hosts', () {
      expect(main('https://evilpaytr.com/'), PaymentNavigation.block);
      expect(main('https://paytr.com.evil.net/'), PaymentNavigation.block);
      expect(main('https://notpaytr.com/'), PaymentNavigation.block);
      expect(main('https://paytr.com@evil.com/'), PaymentNavigation.block);
    });

    test('blocks every scheme but https', () {
      expect(main('http://www.paytr.com/'), PaymentNavigation.block);
      expect(main('javascript:alert(1)'), PaymentNavigation.block);
      expect(main('file:///data/data/app/secret'), PaymentNavigation.block);
      expect(main('intent://scan/#Intent;scheme=zxing;end'), PaymentNavigation.block);
      expect(main('data:text/html,<b>x</b>'), PaymentNavigation.block);
      expect(main('about:blank'), PaymentNavigation.block);
      expect(main('market://details?id=x'), PaymentNavigation.block);
      expect(main('tel:+905550000000'), PaymentNavigation.block);
    });

    test('blocks unparsable text, empty strings and odd ports', () {
      expect(main(''), PaymentNavigation.block);
      expect(main('not a url'), PaymentNavigation.block);
      expect(main('https://'), PaymentNavigation.block);
      expect(main('https://www.paytr.com:8443/'), PaymentNavigation.block);
      expect(main('https://www.paytr.com:443/'), PaymentNavigation.allow);
    });

    test('the configured result host is allowed and its result URL finishes the attempt', () {
      expect(main('https://app.example.com/payment/result?oid=1'), PaymentNavigation.finish);
      expect(main('https://app.example.com/other'), PaymentNavigation.allow);
      expect(main('https://other.example.com/payment/result'), PaymentNavigation.block);
    });

    test('without a configured result host only paytr is reachable', () {
      expect(main('https://app.example.com/payment/result', base: ''), PaymentNavigation.block);
      expect(main('https://app.example.com/payment/result', base: 'http://app.example.com/payment/result'),
          PaymentNavigation.block);
    });

    test('a result path on a paytr host also finishes', () {
      expect(main('https://www.paytr.com/payment/result'), PaymentNavigation.finish);
    });

    test('a result-looking path on a foreign host is blocked, not treated as finished', () {
      expect(main('https://evil.example.net/payment/result'), PaymentNavigation.block);
    });
  });

  group('sub-frames (3-D Secure bank pages)', () {
    test('https frames are allowed, anything else is blocked', () {
      expect(frame('https://acs.bank.example/3ds'), PaymentNavigation.allow);
      expect(frame('http://acs.bank.example/3ds'), PaymentNavigation.block);
      expect(frame('javascript:void(0)'), PaymentNavigation.block);
      expect(frame('file:///etc/passwd'), PaymentNavigation.block);
      expect(frame('https://acs.bank.example:8443/3ds'), PaymentNavigation.block);
    });
  });

  group('isTrustedPaymentStartUrl', () {
    test('only https on a paytr host', () {
      expect(isTrustedPaymentStartUrl('https://www.paytr.com/odeme/guvenli/abc'), isTrue);
      expect(isTrustedPaymentStartUrl('http://www.paytr.com/odeme/guvenli/abc'), isFalse);
      expect(isTrustedPaymentStartUrl('https://evil.example.net/odeme'), isFalse);
      expect(isTrustedPaymentStartUrl('demo://payment/b1'), isFalse);
      expect(isTrustedPaymentStartUrl(''), isFalse);
    });
  });

  group('resultHostOf', () {
    test('returns the lower-cased host of an https URL, otherwise null', () {
      expect(resultHostOf('https://App.Example.com/payment/result'), 'app.example.com');
      expect(resultHostOf('http://app.example.com/payment/result'), isNull);
      expect(resultHostOf(''), isNull);
      expect(resultHostOf('   '), isNull);
    });
  });
}
