---
name: flutter-feature
description: Flutter müşteri uygulamasına yeni ekran veya özellik eklerken izlenecek katman, state ve test prosedürü.
---
# Flutter özellik prosedürü

Klasör yapısı:
```
lib/features/<feature>/
  data/<feature>_repository.dart     # Supabase çağrıları, model dönüşümü
  domain/<model>.dart                # immutable model + fromJson
  presentation/<screen>_screen.dart  # widget
  presentation/<feature>_providers.dart
```

Adımlar:
1. `docs/API_CONTRACT.md` dosyasından kullanılacak RPC'yi veya tabloyu bul. Sözleşmede olmayan bir alan uydurma.
2. Modeli yaz: `final` alanlar, `fromJson`, para için `int ...Kurus`, zaman için `DateTime` (UTC parse edilip `toIstanbul()` ile gösterilir).
3. Repository'yi yaz. `SupabaseClient` dışarıdan verilir (`supabaseClientProvider`). Hatalar `AppException` olarak sarılır ve sözleşmedeki hata kodları Türkçe mesaja çevrilir (`lib/core/errors/`).
4. Provider: okuma için `FutureProvider.autoDispose.family`, yazma için `AsyncNotifier` kullan.
5. Ekranda `AsyncValue.when` ile yükleniyor, hata (tekrar dene butonu) ve boş durumları göster.
6. Route'u `lib/core/router/app_router.dart` dosyasına ekle.
7. Metinleri `lib/core/l10n/strings.dart` dosyasına ekle. Renkleri `context.tokens` (AppTokens) üzerinden kullan; voltaj `highlight` üstüne yalnızca `onHighlight` yazılır (docs/DESIGN.md, ADR-10).
8. Test: model `fromJson` için unit test, kritik ekranlar için widget test (`test/`).
9. `flutter analyze` ve `flutter test` temiz olmalı.
