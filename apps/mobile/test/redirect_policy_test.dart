import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/app_mode/app_mode.dart';
import 'package:halisaha/core/router/app_routes.dart';
import 'package:halisaha/core/router/redirect_policy.dart';

void main() {
  String? go(
    String location, {
    bool restored = true,
    AppMode? mode,
    bool signedIn = false,
    bool profile = false,
    bool onboarding = false,
    bool owner = false,
  }) {
    return decideRedirect(RedirectInput(
      location: location,
      modeRestored: restored,
      mode: mode,
      signedIn: signedIn,
      profileLoaded: profile,
      needsOnboarding: onboarding,
      isOwner: owner,
    ));
  }

  const customerPaths = [
    AppRoutes.home,
    '/venue/abc',
    AppRoutes.bookingSummary,
    AppRoutes.payment,
    '/booking-result/abc',
    AppRoutes.matches,
    AppRoutes.favorites,
    AppRoutes.profile,
    AppRoutes.support,
  ];

  group('mode not restored yet', () {
    test('everything waits on the splash', () {
      expect(go(AppRoutes.home, restored: false), AppRoutes.splash);
      expect(go(AppRoutes.welcome, restored: false, signedIn: true, profile: true), AppRoutes.splash);
      expect(go(AppRoutes.splash, restored: false), isNull);
    });
  });

  group('no mode chosen', () {
    test('only /welcome is allowed, signed in or not', () {
      for (final signedIn in [false, true]) {
        expect(go(AppRoutes.welcome, signedIn: signedIn, profile: signedIn), isNull);
        expect(go(AppRoutes.home, signedIn: signedIn, profile: signedIn), AppRoutes.welcome);
        expect(go(AppRoutes.login, signedIn: signedIn), AppRoutes.welcome);
        expect(go(AppRoutes.owner, signedIn: signedIn, profile: signedIn, owner: true), AppRoutes.welcome);
        expect(go(AppRoutes.splash, signedIn: signedIn), AppRoutes.welcome);
      }
    });
  });

  group('player mode', () {
    const m = AppMode.player;

    test('signed out: login and otp only', () {
      expect(go(AppRoutes.login, mode: m), isNull);
      expect(go(AppRoutes.otp, mode: m), isNull);
      expect(go(AppRoutes.home, mode: m), AppRoutes.login);
      expect(go(AppRoutes.welcome, mode: m), AppRoutes.login);
      expect(go(AppRoutes.splash, mode: m), AppRoutes.login);
      expect(go(AppRoutes.ownerLogin, mode: m), AppRoutes.home);
    });

    test('signed in, profile loading: splash', () {
      expect(go(AppRoutes.home, mode: m, signedIn: true), AppRoutes.splash);
      expect(go(AppRoutes.splash, mode: m, signedIn: true), isNull);
    });

    test('needs onboarding: onboarding (KVKK)', () {
      expect(go(AppRoutes.home, mode: m, signedIn: true, profile: true, onboarding: true), AppRoutes.onboarding);
      expect(go(AppRoutes.onboarding, mode: m, signedIn: true, profile: true, onboarding: true), isNull);
    });

    test('signed in: customer routes stay, auth screens and welcome go home', () {
      for (final p in customerPaths) {
        expect(go(p, mode: m, signedIn: true, profile: true), isNull, reason: p);
      }
      for (final p in [AppRoutes.login, AppRoutes.otp, AppRoutes.onboarding, AppRoutes.splash, AppRoutes.welcome]) {
        expect(go(p, mode: m, signedIn: true, profile: true), AppRoutes.home, reason: p);
      }
    });

    test('owner routes are closed even for an owner account', () {
      for (final owner in [false, true]) {
        for (final p in [AppRoutes.owner, AppRoutes.ownerLogin, AppRoutes.ownerNotOwner, '/owner/anything']) {
          expect(go(p, mode: m, signedIn: true, profile: true, owner: owner), AppRoutes.home, reason: p);
        }
      }
    });
  });

  group('owner mode', () {
    const m = AppMode.owner;

    test('signed out: only the owner login', () {
      expect(go(AppRoutes.ownerLogin, mode: m), isNull);
      for (final p in [...customerPaths, AppRoutes.login, AppRoutes.welcome, AppRoutes.owner, AppRoutes.ownerNotOwner]) {
        expect(go(p, mode: m), AppRoutes.ownerLogin, reason: p);
      }
    });

    test('signed in, profile loading: splash', () {
      expect(go(AppRoutes.owner, mode: m, signedIn: true), AppRoutes.splash);
      expect(go(AppRoutes.splash, mode: m, signedIn: true), isNull);
    });

    test('needs onboarding: onboarding for everyone', () {
      expect(go(AppRoutes.owner, mode: m, signedIn: true, profile: true, onboarding: true, owner: true), AppRoutes.onboarding);
      expect(go(AppRoutes.onboarding, mode: m, signedIn: true, profile: true, onboarding: true, owner: true), isNull);
    });

    test('signed in, not an owner: the not-owner screen', () {
      expect(go(AppRoutes.ownerNotOwner, mode: m, signedIn: true, profile: true), isNull);
      for (final p in [...customerPaths, AppRoutes.owner, AppRoutes.ownerLogin, AppRoutes.splash]) {
        expect(go(p, mode: m, signedIn: true, profile: true), AppRoutes.ownerNotOwner, reason: p);
      }
    });

    test('owner: only /owner, every customer route redirects there', () {
      expect(go(AppRoutes.owner, mode: m, signedIn: true, profile: true, owner: true), isNull);
      expect(go('/owner/sub', mode: m, signedIn: true, profile: true, owner: true), isNull);
      for (final p in [...customerPaths, AppRoutes.ownerLogin, AppRoutes.ownerNotOwner, AppRoutes.splash, AppRoutes.login]) {
        expect(go(p, mode: m, signedIn: true, profile: true, owner: true), AppRoutes.owner, reason: p);
      }
    });
  });
}
