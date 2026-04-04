---
name: "docker-only-audit"
description: "Audits repo for non-Docker dependencies and removes/confines them. Invoke when user wants Docker-only VPS deploys and no host-path assumptions."
---

# Docker-only Audit (Repo Hygiene)

Skill ini fokus memastikan deployment tidak bergantung pada hal di luar Docker: host paths (`/home/ubuntu`, `/opt/...`), cert di host, rclone, systemctl/nginx host, dan UI eksternal.

## Kapan Dipakai

- User minta “hapus yang di luar docker” / “jangan ada dependency VPS host”.
- Deployment sering salah karena ada bind-mount path host yang tidak ada di server baru.

## Pencarian Cepat

Cari indikasi dependency host:

```bash
rg -n "/home/ubuntu|/opt/|/etc/nginx|systemctl|certbot|ufw|fail2ban|rclone|pixel-agents|BACKUP_DIR_HOST|\\.backups" .
```

## Prinsip Perbaikan

- Untuk TLS: jangan mount cert host; prefer Cloudflare proxy (origin HTTP) atau solusi TLS yang konsisten (container/terminator) tapi tetap reproducible.
- Untuk UI statik eksternal: jangan `alias` ke folder yang tidak ada; redirect ke route app (Inertia).
- Untuk backup: jika butuh, harus di-internal-kan dalam Docker (tanpa rclone/host config) atau dihapus dari UI agar tidak membingungkan.

## Verifikasi Setelah Cleanup

```bash
docker compose -f laravel-app/docker-compose.prod.yml config > /dev/null && echo OK
```

