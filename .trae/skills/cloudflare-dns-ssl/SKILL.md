---
name: "cloudflare-dns-ssl"
description: "Guides Cloudflare DNS/SSL setup for this site. Invoke when migrating domains, fixing HTTPS/443 timeouts, nameserver propagation, or cache issues."
---

# Cloudflare DNS + SSL (powerpro.cloud)

Skill ini untuk menangani konfigurasi Cloudflare yang sering membuat migrasi membingungkan: nameserver belum pindah, HTTPS timeout 443, cache 404, atau mode SSL salah.

## Kapan Dipakai

- Status Cloudflare: `Invalid nameservers`, `No certificates`, atau muncul tanda seru “hostname not covered”.
- `https://domain/...` timeout / error 525/526/502.
- Setelah pindah IP, user merasa domain masih ke server lama.

## Checklist DNS (paling cepat)

```bash
dig NS powerpro.cloud +short
dig NS powerpro.cloud @1.1.1.1 +short
dig A  powerpro.cloud @1.1.1.1 +short
```

- Kalau NS masih `dns-parking.com` ⇒ belum pakai Cloudflare penuh.
- Kalau A di 1.1.1.1 jadi IP Cloudflare ⇒ proxy Cloudflare sudah aktif.

## Aturan Praktis SSL Mode

- Origin hanya HTTP (port 80) ⇒ gunakan **Full** (sementara/atau permanen).
- Mau **Full (strict)** ⇒ origin harus punya HTTPS valid (Origin Certificate / Let’s Encrypt) dan port 443 terbuka.

## Cache Asset /build/*

- Jika origin 200 tetapi CDN 404:
  - Purge `https://<domain>/build/*`

## Verifikasi “benar ke server baru”

- Tambahkan header `X-Origin` di origin (sementara) lalu cek:
  - `curl -I https://<domain>/health | grep -i x-origin`
- Alternatif: bandingkan fingerprint SSH host antara IP lama vs baru.

