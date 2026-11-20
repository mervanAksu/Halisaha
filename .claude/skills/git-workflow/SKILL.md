---
name: git-workflow
description: Branch, commit mesajı (Conventional Commits), CHANGELOG ve push kuralları. Commit atmadan önce kullan.
---
# Git iş akışı

- **Branch:** `main` her zaman çalışır durumda tutulur. Özellikler `feat/<kisa-ad>`, düzeltmeler `fix/<kisa-ad>` branch'inde geliştirilir. Erken MVP aşamasında doğrudan `main`'e küçük ve atomik commit atılabilir.
- **Commit formatı:** `<tip>(<kapsam>): <özet>`
  - tip: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`
  - kapsam: `db`, `payments`, `mobile`, `panel`, `agents`, `docs`, `ci`
  - Örnek: `feat(db): add exclusion constraint preventing double booking`
- **Bir commit tek bir mantıksal değişiklik içerir.** Şema ve onu kullanan istemci kodu farklı commit'lerde olabilir, ama migration ile testi aynı commit'te olmalıdır.
- **CHANGELOG:** Her kullanıcıya görünür değişiklik `CHANGELOG.md` dosyasında `## [Unreleased]` başlığına eklenir (Keep a Changelog formatı).
- **Push öncesi:** testler geçiyor olmalı ve `git grep -nE "service_role_key|merchant_key\s*=\s*['\"]\w"` boş dönmeli.
- **Push:** `git push origin <branch>`.
- **Sürüm:** `git tag -a v0.1.0 -m "MVP"` ve `git push --tags`.
