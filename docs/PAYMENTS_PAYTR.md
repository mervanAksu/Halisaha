# PayTR Entegrasyonu

> Sahibi: `payments-engineer`. Bu dosyadaki `VERIFY(paytr)` maddeleri, PayTR pazaryeri sözleşmesi ve geliştirici
> dokümanı (dev.paytr.com) geldiğinde doğrulanacak.

## Akış

```
Mobil                   Supabase (RPC/Edge)                      PayTR
  │ create_booking_hold ──▶ bookings: pending_payment (10 dk)
  │ paytr-create-payment ─▶ start_payment → payments: initiated
  │                         get-token  ───────────────────────────▶ token
  │ ◀── iframe_url ──────────
  │ WebView: ödeme ──────────────────────────────────────────────▶ 3D Secure
  │                         paytr-callback ◀────────── POST (hash) ─┤
  │                         confirm_payment → confirmed | failed | refund_required
  │ booking.status polling ─▶ confirmed ✓
                            paytr-refund (cron) ──── iade ────────▶
```

## Güvenlik kuralları
1. Tutar her zaman DB'den (`bookings.deposit_kurus`) gelir. İstemci tutar göndermez.
2. Rezervasyonu yalnızca hash'i doğrulanmış callback onaylar. Hash formülü: `base64(HMAC_SHA256(merchant_oid + salt + status + total_amount, key))`, karşılaştırma sabit sürede yapılır.
3. Callback idempotenttir. `initiated` dışındaki bir ödeme tekrar işlenmez. PayTR'ye her durumda `OK` döner (bilinmeyen `merchant_oid` veya DB hatası hariç; o durumda PayTR tekrar dener).
4. Geç gelen başarılı ödeme: süre dolmuş ve slot boşsa rezervasyon onaylanır, slot dolmuşsa ödeme `refund_required` olur. Eksik tutar da `refund_required` olur.
5. `merchant_key` ve `merchant_salt` yalnızca `supabase secrets` içinde tutulur ve log'a yazılmaz.

## Ortam değişkenleri (`supabase secrets set`)
`PAYTR_MERCHANT_ID`, `PAYTR_MERCHANT_KEY`, `PAYTR_MERCHANT_SALT`, `PAYTR_TEST_MODE` (1/0),
`PAYTR_PLACEHOLDER_EMAIL_DOMAIN`, `PAYMENT_RESULT_BASE_URL`, `CRON_SECRET`.

## PayTR panel ayarları
- **Bildirim URL:** `https://<proje>.supabase.co/functions/v1/paytr-callback` (`verify_jwt=false`)
- Başarılı ve başarısız dönüş URL'leri yalnızca WebView'in kapanması için kullanılır. Sonuç backend'den okunur.

## İade
`payments.status='refund_required'` → `paytr-refund` fonksiyonu (dakikalık/saatlik cron, `x-cron-secret` header'ı ile)
→ `https://www.paytr.com/odeme/iade` (`merchant_id, merchant_oid, return_amount ("500.00"), paytr_token = base64(HMAC(merchant_id+merchant_oid+return_amount+salt, key))`) → `mark_refunded`.

Cron örneği (Supabase SQL, pg_net):
```sql
select cron.schedule('paytr-refunds', '*/10 * * * *', $$
  select net.http_post(
    url := 'https://<proje>.supabase.co/functions/v1/paytr-refund',
    headers := jsonb_build_object('x-cron-secret', '<CRON_SECRET>')
  ) $$);
```

## Pazaryeri (alt üye işyeri) — VERIFY(paytr)
Araştırma notları (2026-11):
- Alt işyerleri pazaryeri entegrasyonu ile kaydediliyor. Satıcı PayTR'ye ayrıca başvurmuyor.
- Satıcı bazlı komisyonu platform belirliyor. İadede komisyon alınmıyor.
- **Belirsiz:** satıcıya aktarım zamanı (her işlem sonrası mı, teslim onayından sonra mı?) ve `get-token` isteğine eklenecek alt üye işyeri alanları. PayTR'den **yazılı** teyit alınacak.

Kod tarafında hazır olanlar:
- `venues.paytr_submerchant_key` (admin girer), `venues.commission_bps`, `bookings.commission_kurus` (rezervasyon anında sabitlenir)
- `paytr-create-payment` içinde split alanları için yer ayrıldı (`VERIFY(paytr)` yorumu)

Sözleşme geldiğinde yapılacaklar:
- [ ] get-token'a alt üye işyeri / split alanlarını ekle
- [ ] Gerekiyorsa "aktarım onayı" çağrısını maç tamamlanınca (`complete_past_bookings`) tetikle
- [ ] İşletme panelindeki IBAN formunu PayTR alt üye işyeri kayıt API'sine bağla
