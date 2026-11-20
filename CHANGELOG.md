# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürümleme: SemVer.

## [Unreleased]
### Added
- Çok ajanlı geliştirme altyapısı: MASTER_PROMPT, CLAUDE.md, AGENTS.md, 7 alt ajan, 5 skill.
- Ürün dokümanları: PRD, veri modeli, API sözleşmesi, tasarım dili, ADR kayıtları.
- Supabase şeması: sahalar, saha alanları, çalışma saatleri (gece yarısını aşabilir), rezervasyonlar, ödemeler, favoriler.
- Çift rezervasyonu DB seviyesinde engelleyen exclusion constraint; 10 dk ödeme tutma; kullanıcı başına 2 tutma sınırı.
- RLS politikaları ve RPC'ler: müsaitlik, tutma, iptal (iade penceresi), işletme manuel rezervasyon/kapatma, admin onayı.
- Supabase CLI gerektirmeyen SQL test koşucusu ve 14 senaryoluk rezervasyon testi.
