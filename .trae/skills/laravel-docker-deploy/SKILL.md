---
name: "laravel-docker-deploy"
description: "Deploys this repo’s Laravel (laravel-app) via Docker Compose. Invoke when migrating, rebuilding, updating env, or troubleshooting container startup."
---

# Laravel Docker Deploy

Gunakan skill ini untuk deployment aplikasi Laravel/Inertia di folder `laravel-app/` dengan Docker Compose (local/prod), termasuk build image, recreate container, dan langkah verifikasi.

## Kapan Dipakai

- Saat user bilang: deploy/upgrade/migrasi ke VPS baru, “docker compose up”, “image tidak update”, “container restart loop”.
- Saat ada perubahan file Laravel/Vite/Nginx yang harus ter-build dan di-recreate.

## Prinsip

- Stack utama: `web` (nginx) + `app` (php-fpm) + `db` (postgres) + `office_agent_watch`.
- Jangan menjalankan service host (nginx/apache) sebagai dependency—targetnya docker-only.

## Checklist Deploy (Prod)

```bash
cd laravel-app
docker compose -f docker-compose.prod.yml pull || true
docker compose -f docker-compose.prod.yml up -d --build --force-recreate
docker compose -f docker-compose.prod.yml ps
```

Verifikasi:

```bash
curl -sS -I http://127.0.0.1:8080/health | head -n 8
curl -sS -I http://127.0.0.1:8080/login  | head -n 8
docker compose -f docker-compose.prod.yml logs --tail=100 --no-color web
docker compose -f docker-compose.prod.yml logs --tail=100 --no-color app
```

## Update Aman (Tanpa Ganggu DB)

```bash
cd laravel-app
docker compose -f docker-compose.prod.yml up -d --build --no-deps app web office_agent_watch
```

## Pattern Debug Cepat

- Port bentrok:
  - `sudo ss -ltnp | grep ':80|:8080'`
- Web 502/503:
  - cek `app` logs dulu, lalu `web` logs.
- Asset 404:
  - cek `public/build/manifest.json` dari container web.

