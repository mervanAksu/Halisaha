# Halısaha mobile (customer app)

Flutter 3.x / Dart 3 customer app: venue discovery, slot booking with deposit (PayTR iFrame), my matches,
favourites, support and profile. Backend is Supabase (see `../../docs/API_CONTRACT.md`).

Stack: `flutter_riverpod`, `go_router`, `supabase_flutter`, `webview_flutter`, `geolocator`, `url_launcher`,
`cached_network_image`, `google_fonts`, `intl`. No code generation (no `build_runner`).

## Layout

```
lib/
  main.dart, app.dart
  core/        config, l10n/strings.dart (all UI text), theme, router, errors, utils, supabase, widgets
  features/<feature>/{data,domain,presentation}
    auth, venues, booking, matches, favorites, support, profile, notifications (README only)
test/          unit tests (formatters, Istanbul time, error mapping, models) + EmptyState widget test
env/example.json
```

Rules: widgets never call Supabase (repositories + Riverpod providers only); money is `int` kuruş formatted by
`formatTry`; times are stored UTC and displayed in Istanbul time (`UTC+3`, no DST); payment success is decided only
by the backend `bookings.status`.

## First-time setup

The `android/` and `ios/` folders are not committed yet. Generate them in place (requires Flutter >= 3.22 / Dart >= 3.4):

```bash
cd apps/mobile
flutter create . --org com.halisaha --platforms=android,ios --project-name halisaha
# `flutter create` must not touch our sources. If it created or changed any of them, restore:
git checkout -- lib pubspec.yaml analysis_options.yaml test   # (and delete test/widget_test.dart if it was generated)
flutter pub get
```

If `flutter pub get` complains about `intl`, align it with your SDK: `flutter_localizations` pins `intl`
(0.20.x on Flutter >= 3.32, 0.19.x before). Edit the `intl:` line in `pubspec.yaml` accordingly.

### Environment values

```bash
cp env/example.json env/local.json      # env/local.json is git-ignored
# fill in SUPABASE_URL, SUPABASE_ANON_KEY (public anon key only!), SUPPORT_*, WEBSITE_URL, LEGAL_BASE_URL
```

| Key | Use |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase client. Never put the `service_role` key here. |
| `SUPPORT_EMAIL`, `SUPPORT_PHONE`, `SUPPORT_WHATSAPP` | Support screen rows (hidden when empty). WhatsApp: digits with country code, e.g. `905551234567`. |
| `WEBSITE_URL` | Support screen link. |
| `LEGAL_BASE_URL` | Legal pages are opened at `<LEGAL_BASE_URL>/{about,privacy,terms,kvkk,distance-sales}`. |
| `APP_VERSION` (optional) | Shown on the profile screen (default `1.0.0`). |

### Run / test

```bash
flutter run --dart-define-from-file=env/local.json
flutter analyze
flutter test
```

Without the defines the app shows a configuration error screen instead of crashing.

## Native configuration (after `flutter create`)

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Yakınındaki halı sahaları gösterebilmek için konumunu kullanırız.</string>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>tel</string>
  <string>mailto</string>
  <string>whatsapp</string>
  <string>https</string>
</array>
```

Minimum iOS 13 is fine for the pinned plugins; set `platform :ios, '13.0'` in `ios/Podfile` if needed.

### Android (`android/app/src/main/AndroidManifest.xml`)

Inside `<manifest>` (outside `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="whatsapp"/></intent>
</queries>
```

Set `minSdkVersion` to at least 21 (webview_flutter requires 21+; use 23 if a plugin asks for it) in
`android/app/build.gradle(.kts)`.

## Supabase / backend prerequisites

* Phone provider enabled in Supabase Auth (SMS OTP), with rate limits / captcha (ADR-6).
* Edge functions deployed: `paytr-create-payment`, `delete-account` (and `paytr-callback`).
* `PAYMENT_RESULT_BASE_URL` (edge function secret) must contain `/payment/result`; the WebView treats any URL
  containing that string as "attempt finished" and then reads the booking status from the database.
* Storage bucket `venue-photos` is public; the app builds
  `<SUPABASE_URL>/storage/v1/object/public/venue-photos/<path>`.

## Notes

* Fonts: `google_fonts` downloads Inter at runtime and caches it. For offline-first / store builds, bundle the
  font files under `assets/fonts` and register them (see the google_fonts docs) to avoid the first-run download.
* Push notifications are a follow-up: see `lib/features/notifications/README.md`.
