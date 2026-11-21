# Rövanş mobile (customer app + in-app owner panel)

Flutter 3.x / Dart 3 app: venue discovery, slot booking with deposit (PayTR iFrame), my matches,
favourites, support, profile and, for owner/admin accounts, an in-app **işletmeci paneli**. Backend is Supabase
(see `../../docs/API_CONTRACT.md`). Brand: **Rövanş** (`AppConfig.appName`); the Dart package is still named
`halisaha` (imports in tests use it), the store/bundle identity is `com.rovans.app` (docs/DESIGN.md).

Stack: `flutter_riverpod`, `go_router`, `supabase_flutter`, `webview_flutter`, `geolocator`, `url_launcher`,
`cached_network_image`, `google_fonts` (Inter + Barlow Condensed), `flutter_secure_storage`, `intl`. No code generation
(no `build_runner`) and no UI kit: `ThemeData` / `ColorScheme` are built by hand from the design tokens.

## Layout

```
lib/
  main.dart, app.dart
  core/        config, l10n/strings.dart (all UI text), theme (tokens), security, router, errors, utils, supabase, widgets
  features/<feature>/{data,domain,presentation}
    auth, venues, booking, matches, favorites, support, profile, owner, notifications (README only)
  demo/        in-memory repositories for the web preview (incl. DemoOwnerRepository)
test/          unit tests: formatters, Istanbul time, error mapping, models, token contrast (WCAG), slot grouping,
               owner logic (business day, grid), demo owner repository, secure storage, WebView allow-list, URL safety
env/example.json
```

## Theme (docs/DESIGN.md)

* `core/theme/app_tokens.dart`: `AppTokens` (`ThemeExtension`) with the "Skorbord" light and dark values (docs/DESIGN.md, ADR-10). Text on `highlight` is always `onHighlight`.
  Widgets read colours with `context.tokens` (falls back to light tokens when a theme lacks the extension).
  **No colour literal exists outside `core/theme/`.** `accent` (#22B573) is only for icons/rings/progress, never a text
  background; green surfaces with text use `action`.
* `app_theme.dart`: `AppTheme.light()` / `AppTheme.dark()`, `MaterialApp.themeMode = ThemeMode.system`.
* `app_text.dart`: `numericStyle()` = Barlow Condensed for times, prices and big numbers.
* `test/theme_contrast_test.dart` computes the WCAG contrast of every text/background pair (>= 4.5:1) in both themes.
  One deliberate deviation from DESIGN.md: light `onDisabledSlot` is `#656C78` (the documented `#6B7280` is 4.32:1 on
  `#F1F2F4`). Do not use `textSecondary` on `accentSoft` in the light theme (4.35:1); use `textPrimary` there.

## UX rules implemented

Slot picker grouped Akşam (17:00-23:59) / Öğleden sonra (12:00-16:59) / Sabah-Gece (rest), booked slots grey with a
"Dolu" label (no strikethrough), past slots hidden, 3 columns (2 above 1.3x text scale), 48 dp targets; sticky summary
bar with time, total and "Şimdi X ₺ kapora · kalan sahada"; one-line cancellation policy; empty day shows
"En yakın boş gün: <gün>" (searches the following days of the 14-day strip through `availabilityProvider`);
"Güvenli ödeme · PayTR" on the summary; confirmation shows weekday + date, tappable address (Maps), paid deposit,
remainder and the policy.

## In-app owner mode (İşletmeci paneli)

* Profil shows **İşletmeci paneli** when `profiles.role` is `owner` or `admin`; route `/owner` is redirected to `/` for
  everyone else (RLS enforces it on the server anyway).
* The owner shell is **always light** and has four tabs:
  * **Bugün**: date strip (yesterday .. +13 days, business-day rule: before 06:00 Istanbul "today" is still yesterday),
    venue switcher when the owner has several venues, and a pitch x time grid. Colours: app booking = `action`,
    phone booking = `primary`, closed slot = grey striped, unpaid hold = `warning`. Tap a free slot: sheet with
    "Telefon rezervasyonu" (name, phone, note) or "Saati kapat" (`owner_create_manual_booking`). Tap a booking: details
    (app customer name/phone through `owner_customer_contacts`; manual ones use `customer_name`/`customer_phone`),
    **İptal et** (hidden once started; warns that app bookings get a full deposit refund; `slot_started` is mapped),
    **Geldi / Gelmedi** for started bookings (`owner_mark_attendance`).
  * **Rezervasyonlar**: upcoming list with filters (Tümü, Uygulama, Telefon, Kapalı, Ödeme bekleyen).
  * **Sahalarım**: price, deposit, active switch (table `pitches`); deposit must not exceed the slot price.
  * **Saatler**: weekly hours editor (`venue_hours` upsert; a closed day deletes its row; closing at or before opening
    is allowed and flagged "Gece yarısını aşar").
* Data goes through `OwnerRepository` (`features/owner/data`) and Riverpod providers; widgets never call Supabase.
* Admin accounts only see venues they own (`venues.owner_id = auth.uid()`).

Demo: Profil has the switch **İşletmeci modunu dene (demo)**; it makes the demo user the owner of two demo venues
(Mavi Çim 09-23, Gece Kuşu 12-06) served by the in-memory `DemoOwnerRepository` with a mix of app / phone / closed /
unpaid bookings. Owner changes in the demo do not affect the customer-side demo availability.

## Security notes

* **Session storage:** on mobile `Supabase.initialize` gets `FlutterAuthClientOptions(localStorage: SecureLocalStorage(...))`
  (`core/security/secure_local_storage.dart`), backed by `flutter_secure_storage` (iOS Keychain `first_unlock_this_device`,
  Android EncryptedSharedPreferences/Keystore). Web keeps the SDK default. The PKCE code verifier still uses the SDK's
  own storage (short lived).
* **Payment WebView:** `decidePaymentNavigation` (`features/booking/domain/payment_url_policy.dart`) allows main-frame
  navigations only over https to `*.paytr.com` and the host of `PAYMENT_RESULT_BASE_URL`; everything else is
  `NavigationDecision.prevent`. The result URL on an allowed host ends the attempt and the result screen then reads
  the booking status from the backend. No `JavaScriptChannel` is registered, and `file:`/`intent:`/`javascript:` URLs are
  blocked by the same policy. The first page must itself be an https PayTR URL (`isTrustedPaymentStartUrl`).
  Sub-frame requests (the bank's 3-D Secure page is framed by PayTR) are limited to https only.
* **url_launcher:** `openExternalUrl` refuses anything but `https`, `tel` and `mailto` (`isSafeExternalUrl`). Only URLs
  the app builds (Maps, support contacts, legal pages, `tel:` from `telUrl`) are launched.
* **Logging:** the app does not log. Never add `print`/`debugPrint` of tokens, sessions or phone numbers.

Rules: widgets never call Supabase (repositories + Riverpod providers only); money is `int` kuruş formatted by
`formatTry`; times are stored UTC and displayed in Istanbul time (`UTC+3`, no DST); payment success is decided only
by the backend `bookings.status`.

## First-time setup

The `android/` and `ios/` folders are not committed yet. Generate them in place (requires Flutter >= 3.22 / Dart >= 3.4):

```bash
cd apps/mobile
flutter create . --org com.rovans --platforms=android,ios --project-name halisaha
# `flutter create` must not touch our sources. If it created or changed any of them, restore:
git checkout -- lib pubspec.yaml analysis_options.yaml test   # (and delete test/widget_test.dart if it was generated)
flutter pub get
```

If `flutter pub get` complains about `intl`, align it with your SDK: `flutter_localizations` pins `intl`
(0.20.x on Flutter >= 3.32, 0.19.x before). Edit the `intl:` line in `pubspec.yaml` accordingly.

After `flutter create`, set the Android `applicationId` and the iOS bundle identifier to `com.rovans.app`
(docs/DESIGN.md: identity is fixed) and add `flutter_secure_storage` requirements: Android `minSdkVersion 23`
(EncryptedSharedPreferences) and, on iOS, the Keychain works without extra entitlements.

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
| `PAYMENT_RESULT_BASE_URL` | Same value as the edge function secret. Its host is the only non-PayTR host the payment WebView may open. |
| `APP_VERSION` (optional) | Shown on the profile screen (default `1.0.0`). |

### Run / test

```bash
flutter run --dart-define-from-file=env/local.json
flutter analyze
flutter test
```

Without the defines the app shows a configuration error screen instead of crashing.

## Demo / web önizleme

Backend'siz demo modu: Supabase başlatılmaz, PayTR/WebView kullanılmaz, tüm veri bellekte tutulur
(sayfa yenilenince sıfırlanır). Uygulama "Demo Oyuncu" olarak giriş yapmış açılır.

```bash
cd apps/mobile
flutter run -d chrome --dart-define=DEMO_MODE=true
```

GitHub Pages için derleme (CI):

```bash
flutter build web --release --dart-define=DEMO_MODE=true --base-href /Halisaha/
```

Notlar:

* `lib/demo/` altında repository sınıflarının bellek içi karşılıkları vardır (`implements`), `main.dart` bunları
  kök `ProviderScope`'a override eder. `AppConfig.demoMode` kapalıyken hiçbir demo kodu çalışmaz.
* Kurgusal 6 saha (biri 12:00-06:00 gece sahası), 14 günlük deterministik müsaitlik (tarih + saha ile tohumlanır;
  sunucudaki gibi 15 dakika içinde başlayan slotlar `past`), 2 geçmiş + 1 gelecek örnek maç.
* Ödeme: "Demo ödeme" ekranında "Ödemeyi tamamla (demo)" veya "Başarısız ödeme dene (demo)". Sonuç ekranı yine
  rezervasyon durumunu okur (bellek içi).
* Çıkış yap / hesabı sil demo modunda kapalıdır ("Demo modunda bu işlem kapalı").
* Web yönlendirmesi: go_router'ın varsayılan hash stratejisi (`/Halisaha/#/...`) kullanılır; GitHub Pages'te 404
  yönlendirmesi gerekmez. `web/index.html` repoda tutulur (`flutter create` gerekmez).
* Demo olmayan web derlemesinde gerçek ödeme desteklenmez ("Web'de ödeme desteklenmiyor").

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

Set `minSdkVersion` to at least 23 (flutter_secure_storage needs 23; webview_flutter needs 21+) in
`android/app/build.gradle(.kts)`.

## Supabase / backend prerequisites

* Phone provider enabled in Supabase Auth (SMS OTP), with rate limits / captcha (ADR-6).
* Edge functions deployed: `paytr-create-payment`, `delete-account` (and `paytr-callback`).
* `PAYMENT_RESULT_BASE_URL` (edge function secret) must contain `/payment/result` and must also be passed to the app
  build (`PAYMENT_RESULT_BASE_URL` define); the WebView treats an allowed-host URL containing that string as
  "attempt finished" and then reads the booking status from the database.
* Storage bucket `venue-photos` is public; the app builds
  `<SUPABASE_URL>/storage/v1/object/public/venue-photos/<path>`.

## Notes

* Fonts: `google_fonts` downloads Inter at runtime and caches it. For offline-first / store builds, bundle the
  font files under `assets/fonts` and register them (see the google_fonts docs) to avoid the first-run download.
* Push notifications are a follow-up: see `lib/features/notifications/README.md`.
