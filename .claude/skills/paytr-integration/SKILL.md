---
name: paytr-integration
description: PayTR iFrame ödeme token'ı alma, callback doğrulama, iade ve pazaryeri alt üye işyeri işlemleri için prosedür ve güvenlik kuralları.
---
# PayTR entegrasyonu

Ayrıntılı referans: `docs/PAYMENTS_PAYTR.md`. Ortak kod: `supabase/functions/_shared/paytr.ts`.

## Akış
1. İstemci `create_booking_hold` RPC'sini çağırır ve `pending_payment` durumunda bir booking alır (10 dk tutma).
2. İstemci `paytr-create-payment` Edge Function'ını `booking_id` ile çağırır. Fonksiyon şunları yapar:
   - Booking'in kullanıcıya ait olduğunu, durumunun `pending_payment` olduğunu ve süresinin dolmadığını doğrular.
   - Tutarı DB'den alır (`deposit_kurus`).
   - `paytr_token = base64(HMAC_SHA256(merchant_id+user_ip+merchant_oid+email+payment_amount+user_basket+no_installment+max_installment+currency+test_mode + merchant_salt, merchant_key))` hesaplar.
   - `POST https://www.paytr.com/odeme/api/get-token` isteğini atar ve dönen `token` ile `https://www.paytr.com/odeme/guvenli/<token>` adresini döndürür.
3. Uygulama bu adresi WebView'de açar. Kullanıcı ödemeyi tamamlar.
4. PayTR sunucusu `paytr-callback` fonksiyonuna POST atar. Fonksiyon şunları yapar:
   - `hash == base64(HMAC_SHA256(merchant_oid + merchant_salt + status + total_amount, merchant_key))` kontrolü yapar. Hash tutmazsa 400 döner ve hiçbir şey yapmaz.
   - `confirm_payment` RPC'sini (service role) çağırır. Bu çağrı idempotenttir.
   - **Her durumda** düz metin `OK` döner. PayTR, `OK` alana kadar callback'i tekrar gönderir.
5. Uygulama ödeme sonrası booking durumunu **backend'den** okur (polling veya realtime).

## Kurallar
- `merchant_oid` alfanümeriktir, tire ve alt çizgi içermez. Bizde `HS` + booking id'nin tiresiz hali kullanılır.
- `payment_amount` kuruş cinsinden tamsayıdır (100 TL = 10000).
- Test modunda `test_mode=1` gönderilir. Canlıya geçişte panelde callback URL tanımlanır.
- Pazaryeri (alt üye işyeri) ve transfer alanları PayTR sözleşmesinden sonra gelen dokümana göre doğrulanır. Emin olunmayan alanlar `VERIFY(paytr)` ile işaretlenir.
- İade: `confirm_payment` sonucu `refund_required` ise `paytr-refund` fonksiyonu tetiklenir.
