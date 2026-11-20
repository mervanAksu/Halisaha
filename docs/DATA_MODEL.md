# Veri Modeli

Tek doğruluk kaynağı: `supabase/migrations/`. Bu dosya özet ve gerekçedir.

```
auth.users 1─1 profiles (role: customer|owner|admin)
profiles 1─* venues (owner_id)
venues 1─1 venue_payout_accounts (IBAN; yalnızca sahibi + admin görür)
venues 1─* venue_hours (iso_weekday, open_time, close_time; close<=open → gece yarısını aşar)
venues 1─* pitches (hourly_price_kurus, deposit_kurus, slot_minutes)
pitches 1─* bookings (source: app|manual|block; status: pending_payment|confirmed|cancelled|expired|completed|no_show)
bookings 1─* payments (merchant_oid unique; status: initiated|succeeded|failed|refund_required|refunded)
profiles *─* venues  via favorites
profiles 1─* device_tokens
```

## Kritik kurallar
- **Çift rezervasyon:** `bookings.no_overlapping_bookings`, yani `EXCLUDE USING gist (pitch_id =, tstzrange(starts_at, ends_at) &&) WHERE status IN ('pending_payment','confirmed')`.
- **Tutma (hold):** `pending_payment` + `hold_expires_at = now()+10dk`. `expire_stale_holds()` dakikada bir (pg_cron) ve her yeni rezervasyon öncesi çalışır.
- **Bir rezervasyonda en fazla bir başarılı ödeme olabilir:** `payments_one_success_per_booking` partial unique index.
- **Komisyon:** `commission_kurus = deposit_kurus × venues.commission_bps / 10000` (varsayılan %10). Rezervasyon anında sabitlenir.
- **Durum geçişleri:**
  - `pending_payment → confirmed` (ödeme başarılı) | `cancelled` (müşteri) | `expired` (süre doldu)
  - `expired → confirmed` (geç gelen başarılı ödeme, slot hâlâ boşsa; doluysa ödeme `refund_required`)
  - `confirmed → cancelled` (müşteri/işletme) | `completed` (cron, bitiş saatinden sonra) | `no_show` (işletme)
- **Silinen kullanıcı:** `bookings.user_id` ve `payments.user_id` alanları `set null` olur. Mali kayıt korunur.

## İndeksler
`bookings(user_id, starts_at desc)`, `bookings(venue_id, starts_at)`, `bookings(hold_expires_at) where pending`, `venues(status, district)`.
