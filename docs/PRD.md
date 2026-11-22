# Ürün Gereksinimleri (PRD)

## Problem
Halı saha rezervasyonu hâlâ çoğunlukla telefonla yapılıyor. Oyuncu hangi sahanın hangi saatte boş olduğunu bilmiyor.
İşletme sahibi defterle veya WhatsApp'la takip ediyor ve son dakika iptallerinde (no-show) para kaybediyor.

## Çözüm
Oyuncunun yakınındaki sahaların boş saatlerini görüp **kapora ödeyerek** saniyeler içinde rezervasyon yaptığı mobil
uygulama. Kapora işletmeyi no-show'a karşı korur. İşletme takvimini tek bir panelden yönetir.

## Kullanıcılar
- **Oyuncu / takım kaptanı** (mobil): 18-40 yaş, haftada 1-2 maç, genelde akşam 19:00-24:00.
- **İşletme sahibi** (web panel): 1-5 sahası olan tesis. Telefonla gelen rezervasyonları da sisteme girmesi gerekir.
- **Admin** (web panel): platform ekibi. Sahaları onaylar, komisyonu belirler, iade ve şikâyetleri yönetir.

## v1 kapsamı (MVP)

### Mobil uygulama
| # | Özellik | Kabul kriteri |
|---|---|---|
| M1 | Telefonla giriş (SMS OTP) | Numara gir → 6 haneli kod → ilk girişte ad soyad + KVKK aydınlatma onayı |
| M2 | Saha listesi (ana sayfa) | Arama kutusu, konum filtresi (önce il, sonra o ilin bir veya birden çok ilçesi; yalnızca sahası olan il/ilçeler listelenir, seçim cihazda hatırlanır), kart: kapak foto, ad, bugünkü çalışma saati, ilçe, en düşük saatlik fiyat, "Sahayı görüntüle". Konum izni verilirse yakınlığa göre sıralanır |
| M3 | Saha detayı | Foto galerisi, adres + haritada aç, olanaklar, saha (pitch) seçici, 14 günlük tarih şeridi, slot ızgarası (dolu/boş/geçmiş), favori butonu |
| M4 | Rezervasyon özeti | Saha, tarih-saat, toplam ücret, **şimdi ödenecek kapora**, sahada ödenecek kalan, iptal politikası, mesafeli satış sözleşmesi onay kutusu |
| M5 | Ödeme | PayTR iFrame WebView. Sonuç ekranı booking durumunu backend'den okur. 10 dk geri sayım gösterilir |
| M6 | Maçlarım | "Gelecek" / "Geçmiş" sekmeleri, boş durumda "Saha ara" butonu, kartta durum etiketi, gelecekteki maçta "İptal et" (iade olup olmayacağı önceden gösterilir) |
| M7 | Favorilerim | Favori sahalar listesi |
| M8 | Destek | E-posta, telefon, WhatsApp, web sitesi, SSS (akordeon) |
| M9 | Profilim | Ad ve telefon, profili düzenle, bildirim ayarları, Hakkında, Gizlilik Politikası, Kullanım Koşulları, KVKK Aydınlatma Metni, Mesafeli Satış Sözleşmesi, Çıkış, **Hesabımı sil** |
| M10 | Push bildirim (**v1.1'e ertelendi**) | Rezervasyon onaylandı, maçtan 2 saat önce hatırlatma, işletme iptal etti. `device_tokens` tablosu hazır, FCM entegrasyonu `apps/mobile/lib/features/notifications/README.md` dosyasında |

### İşletme paneli (web)
| # | Özellik | Kabul kriteri |
|---|---|---|
| P1 | Giriş | E-posta + şifre. Yalnızca `owner` veya `admin` rolü girebilir |
| P2 | Takvim | Saha bazlı gün görünümü (hafta görünümü v1.1). Uygulama rezervasyonu, manuel rezervasyon, kapalı saat ve bekleyen ödeme farklı renkte. Tıklayınca detay |
| P3 | Manuel rezervasyon / saat kapatma | Boş slota tıkla → müşteri adı ve telefonu gir veya "kapat" → `owner_create_manual_booking` |
| P4 | Rezervasyon listesi | Filtre (tarih, durum), iptal (uygulama rezervasyonunda iade uyarısı), geldi / gelmedi işaretleme |
| P5 | Tesis ayarları | Bilgiler, fotoğraflar, haftalık çalışma saatleri (gece yarısını aşabilir), iptal penceresi |
| P6 | Sahalar | Saha ekle/düzenle: ad, format, kapalı/açık, saatlik ücret, kapora, slot süresi, aktif/pasif |
| P7 | Ödeme bilgileri | Ünvan, VKN/TCKN, IBAN (PayTR alt üye işyeri kaydı için) |
| P8 | Admin | Saha onayı/askıya alma, komisyon oranı, iade bekleyen ödemeler listesi |

## v1.1
- Push bildirimleri (M10)
- Panelde hafta görünümü ve çoklu slot kapatma
- Kampanya sayacı ("5 maç oyna, 6. maçın kaporası bizden")
- Saha puanlama ve yorum
- Takım arkadaşlarını davet ve kaporayı bölüşme
- İşletme için doluluk ve gelir raporu

## Sonrası
- Rakip/oyuncu bulma (eksik oyuncu ilanı), lig/turnuva modülü
- İşletme için abonelik (premium görünürlük)
- Diğer şehirler

## Ölçülecek metrikler
- Arz: aktif saha sayısı, panelden yönetilen slot oranı (manuel girişler dahil)
- Talep: haftalık rezervasyon, ödeme başarı oranı (hold → confirmed), 30 günlük tekrar rezervasyon
- Sağlık: no-show oranı, iptal oranı, iade sayısı, destek talebi / rezervasyon
