---
name: "inertia-vite-assets"
description: "Fixes Inertia/Vite asset issues (404, mismatched manifest, caching). Invoke when login loads but CSS/JS is missing or /build/* errors."
---

# Inertia + Vite Assets

Skill ini untuk masalah frontend Laravel/Inertia (React) yang terkait Vite build: asset 404, `manifest.json` mismatch, atau cache CDN.

## Kapan Dipakai

- Halaman HTML tampil tapi CSS/JS tidak load.
- Error 404 pada `/build/assets/...` atau `manifest.json`.
- Setelah rebuild, browser masih pakai file lama (cache).

## Checklist Origin (Docker)

```bash
docker compose -f laravel-app/docker-compose.prod.yml ps
docker exec laravel-app-web-1 sh -lc 'ls -la /var/www/html/public/build | head -n 30'
docker exec laravel-app-web-1 sh -lc 'ls -la /var/www/html/public/build/assets | head -n 30'
curl -sS -I http://127.0.0.1:8080/build/manifest.json | head -n 10
```

Kalau origin sudah 200 tapi via domain masih 404:

- Itu biasanya cache CDN. Purge cache khusus:
  - `https://<domain>/build/*`

## Tips Uji Tanpa Salah Copy URL

Header `Link:` sering menampilkan format `</build/assets/...>; rel=...`:
- URL yang benar hanya path di dalam `< >`.
- Jangan sertakan karakter `;` atau backtick.

## Jika Perlu Rebuild & Recreate

```bash
cd laravel-app
docker compose -f docker-compose.prod.yml build web app
docker compose -f docker-compose.prod.yml up -d --force-recreate web app
```

