# Mimari Karar Kayıtları (ADR)

Format: bağlam → karar → sonuç. Yeni karar en alta eklenir. Eski kararlar silinmez; gerekirse "yerini aldı: ADR-N" notu düşülür.

## ADR-1 · Flutter + Supabase (2026-11-20)
Bağlam: Tek geliştirici, iOS + Android, ilişkisel ve çakışmaya duyarlı rezervasyon verisi.
Karar: Mobil için Flutter, backend için Supabase (Postgres + RLS + Edge Functions).
Sonuç: Çift rezervasyon DB kısıtıyla çözülür. Tek kod tabanı kullanılır. Firebase'e göre SQL raporlaması kolaydır. Vendor bağımlılığı düşüktür (Postgres taşınabilir).

## ADR-2 · İşletme paneli Next.js (2026-11-20)
Karar: Panel ayrı bir Next.js uygulaması olur. Flutter web kullanılmaz.
Sonuç: Takvim ve tablo ağırlıklı masaüstü arayüz için web ekosistemi daha olgun. Edge Functions ile aynı dil (TypeScript) kullanılır.

## ADR-3 · Pazaryeri modeli, PayTR (2026-11-20)
Bağlam: Platformun müşteri parasını tutması 6493 sayılı Kanun kapsamında ödeme kuruluşu lisansı gerektirebilir.
Karar: Kapora PayTR Pazaryeri (alt üye işyeri) ile tahsil edilir. Platform komisyonu PayTR tarafından ayrılır, kalan tutar işletmeye aktarılır.
Sonuç: Alt üye işyeri kaydı ve transfer API ayrıntıları PayTR sözleşmesinden sonra doğrulanır (`VERIFY(paytr)` işaretleri). Komisyon kapora üzerinden alınır.

## ADR-4 · Komisyon yalnızca kapora üzerinden (2026-11-20)
Karar: Kalan ücret sahada nakit veya POS ile ödenir. Platform yalnızca kaporadan `commission_bps` keser.
Sonuç: İşletmeye "sana ek iş yükü yok, sadece kapora online" mesajı verilir. Gelir modeli kapora tutarına bağlıdır, bu nedenle ileride abonelik eklenebilir.

## ADR-5 · Rezervasyon tutma süresi 10 dakika, kullanıcı başına en fazla 2 tutma (2026-11-20)
Karar: Ödeme için 10 dk süre verilir. Kötüye kullanıma (saatleri ödemeden kilitleme) karşı aynı anda en fazla 2 bekleyen tutma olabilir.

## ADR-6 · Müşteri girişi telefon OTP, işletme girişi e-posta (2026-11-20)
Karar: Müşteriler telefon numarasıyla girer (sahaların zaten telefonla iletişim kurduğu bir kitle). İşletme panelinde e-posta ve şifre kullanılır.
Sonuç: SMS maliyeti oluşur ve SMS pumping riski vardır. Supabase Auth rate limit ve captcha (hCaptcha/Turnstile) açılmalıdır.

## ADR-7 · Flutter 3.47 `material_ui` geçişi ertelendi (2026-11-20)
Bağlam: CI'daki Flutter 3.47, `package:flutter/material.dart` importunu kullanımdan kaldırılmış (deprecated) olarak işaretliyor. Yerine `package:material_ui` geliyor.
Karar: v1'de `material.dart` ile devam ediliyor ve `flutter analyze --no-fatal-infos` kullanılıyor. Geçiş, paket kararlı hale gelince tek bir PR ile yapılacak.
Sonuç: CI bilgi notlarını raporlar ama başarısız olmaz. Uyarı (warning) ve hatalar hâlâ CI'ı başarısız yapar.

## ADR-8 · Marka "Rövanş", paket kimliği com.rovans.app, tasarım A+B (2026-11-21)
Bağlam: "Halısaha" adı ayırt edici değil ve korunamaz. "Saha…" ve "Maç…" ile başlayan çok sayıda uygulama var.
Karar: Ad "Rövanş", paket kimliği `com.rovans.app` (değiştirilemez). Tasarım: açık "Temiz Çim" varsayılan, sistem koyu modunda "Gece Maçı". Ek UI kiti kullanılmıyor (Material 3 + kendi tokenlarımız). Ayrıntı: `docs/DESIGN.md`.
Sonuç: Marka için TÜRKPATENT başvurusu yapılmalı. Kontrast kuralları (`#22B573` üzerine beyaz yazı yok) testle korunuyor.

## ADR-9 · Kaporasız mod ile erken yayın seçeneği (2026-11-21)
Bağlam: PayTR ve kurumsal mağaza hesapları şirket kuruluşuna bağlı.
Karar: `deposit_kurus = 0` olan sahalarda rezervasyon ödeme olmadan onaylanır. Bu davranış zaten şemada var ve kötüye kullanım sınırlarıyla korunuyor. İlk işletmelerle ödeme altyapısı olmadan canlıya çıkılabilir.
Sonuç: No-show koruması bu modda yok. İşletmeye bunun söylenmesi ve kara liste özelliğinin v1.1'e alınması gerekir.
