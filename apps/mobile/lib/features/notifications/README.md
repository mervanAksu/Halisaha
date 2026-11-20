# Push notifications (v1 follow-up)

Status: **not implemented yet.** No Firebase packages are in `pubspec.yaml` on purpose, so the app builds
without a Firebase project. This note describes how to add FCM (PRD M10).

## Events to deliver
| Event | Sent by | Audience |
|---|---|---|
| Booking confirmed | DB trigger / edge function after `confirm_payment` succeeds | customer |
| Reminder 2 hours before the match | pg_cron job over `bookings` (`status='confirmed'`, `starts_at - now() ~ 2h`) | customer |
| Venue cancelled the booking | after `owner_cancel_booking` | customer |

Sending is done server-side (an edge function using the FCM HTTP v1 API with a service account kept in
Supabase secrets). The client only registers its token.

## `device_tokens` table contract
From `supabase/migrations/20261120090000_core_schema.sql`:

```
device_tokens(
  token       text primary key,
  user_id     uuid not null references profiles(id) on delete cascade,   -- defaults to auth.uid()
  platform    text not null check (platform in ('ios','android')),
  updated_at  timestamptz not null default now()
)
```
RLS: the owner may select / insert / update / delete their own rows (`user_id = auth.uid()`).
Rows are removed by cascade when the account is deleted.

Client upsert (inside a repository, never from a widget):

```dart
await client.from('device_tokens').upsert({
  'token': token,
  'platform': Platform.isIOS ? 'ios' : 'android',
  'updated_at': DateTime.now().toUtc().toIso8601String(),
}, onConflict: 'token');
```
Note: `token` is the primary key, so when a different user signs in on the same device the upsert must
re-assign the row. The `update` policy only matches rows the caller already owns, so delete the token on sign-out
(see below) to avoid a conflict.

## Integration steps
1. Create a Firebase project; add the Android (`com.halisaha.halisaha`) and iOS apps. Put
   `google-services.json` / `GoogleService-Info.plist` in the native folders (do not commit secrets that
   belong to the project owner; these files are client config but keep them out of public forks if desired).
2. Add dependencies: `firebase_core`, `firebase_messaging` (and `flutter_local_notifications` if you want
   foreground banners). Run `flutterfire configure`.
3. iOS: enable Push Notifications + Background Modes (Remote notifications) capabilities and upload the APNs key in
   Firebase. Android 13+: request the `POST_NOTIFICATIONS` runtime permission.
4. Create `lib/features/notifications/data/notifications_repository.dart` that wraps `FirebaseMessaging` and the
   `device_tokens` upsert/delete above, plus a Riverpod provider.
5. On sign-in (after the profile exists): request permission, fetch the token, upsert it, and listen to
   `onTokenRefresh`. On sign-out and before account deletion: delete the current token row.
6. Handle taps: `FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage` → route to `/matches`
   (data payload suggestion: `{ "type": "booking_confirmed" | "reminder" | "venue_cancelled", "booking_id": "<uuid>" }`).
7. Replace the placeholder toggles in `features/profile/presentation/notification_settings_screen.dart` with
   persisted preferences (needs a contract addition, e.g. a `notification_prefs` column, in `docs/API_CONTRACT.md`
   first).
