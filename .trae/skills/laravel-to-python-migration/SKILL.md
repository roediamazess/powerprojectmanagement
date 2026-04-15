---
name: "laravel-to-python-migration"
description: "Plans and executes migrating a Laravel app (DB + auth + APIs) to Python/FastAPI. Invoke when user asks to replace Laravel, map schema, import data, or cut over production traffic."
---

# Laravel → Python Migration (FastAPI)

Gunakan skill ini saat user ingin mengganti Laravel menjadi backend Python (FastAPI), termasuk pemetaan skema database, migrasi data, auth/login, dan cutover production.

## Tujuan

- Menjadikan FastAPI sebagai sumber data utama (source of truth).
- Memetakan skema Laravel ke skema baru (SQLAlchemy/Alembic) tanpa kehilangan data penting.
- Memastikan login/auth berfungsi (cookie session + CSRF) dan bisa diakses via domain production.
- Menyiapkan tahapan cutover yang aman + rollback.

## Langkah Kerja (Playbook)

### 1) Inventarisasi

- Daftar modul/tabel Laravel yang dipakai UI: partners, projects, time_boxings, users/roles/permissions, audit_logs, dll.
- Daftar endpoint yang dipanggil frontend dan response contract-nya.
- Tentukan strategi migrasi:
  - **A. Dual-DB sementara**: FastAPI bisa read dari DB Laravel untuk endpoint tertentu selama masa transisi.
  - **B. Full import**: migrasikan semua data ke DB FastAPI lalu matikan dependency ke DB Laravel.

### 2) Skema & Mapping

- Identifikasi perbedaan:
  - Laravel sering: `id` integer, banyak kolom string, multi-tenant via `tenant_id`.
  - FastAPI/SQLAlchemy di repo ini sering: `id` UUID, beberapa atribut direlasikan via `lookup_values` (FK) bukan string langsung.
- Tentukan mapping per tabel:
  - Field direct copy (cnc_id, name, star, address, area, sub_area, dll).
  - Field yang perlu normalisasi jadi lookup:
    - contoh: `status` (string) → `status_id` (FK lookup_values).
  - Field yang perlu dipindah ke tabel relasi:
    - contoh: banyak email role di Laravel → `partner_contacts` (role_key + email).
  - Tenant:
    - Jika skema FastAPI belum ada `tenant_id`, tentukan opsi:
      - tambah kolom `tenant_id` pada semua entitas yang perlu multi-tenant, atau
      - buat layer “workspace” lain, atau
      - sementara single-tenant dan enforce di level infra.

### 3) Migrasi Data (Script)

- Buat script import yang:
  - konek ke DB Laravel (read-only) dan DB FastAPI (write).
  - upsert berdasarkan natural key (`cnc_id`/email) agar bisa di-run berulang (idempotent).
  - commit per batch agar stabil.
  - normalisasi lookup (create category/value jika belum ada).
  - mapping kontak/email ke tabel relasi.
- Verifikasi:
  - hitung total records sumber vs target.
  - sampling random 20 baris, bandingkan field kritikal.
  - cek constraint unik (cnc_id/email) tidak konflik.

### 4) Auth & Login

- Pastikan flow login:
  - `GET /api/auth/csrf` set cookie CSRF.
  - `POST /api/auth/login` validasi password dan set session cookie.
  - `GET /api/auth/me` mengembalikan profil.
- Pastikan setting cookie untuk production:
  - `COOKIE_SECURE=true` (HTTPS)
  - `COOKIE_SAMESITE=lax` (atau `none` jika cross-site benar-benar diperlukan; butuh `secure=true`)
  - `CORS_ORIGINS=https://<domain>`
- Seed/admin user:
  - jangan hardcode credential di repo.
  - gunakan env `ADMIN_EMAIL`, `ADMIN_PASSWORD` untuk bootstrap.

### 5) Frontend Cutover

- Pastikan frontend memanggil `/api/*` pada domain yang sama (lebih stabil) sehingga cookie/session jalan.
- Jika frontend beda domain/subdomain:
  - perhatikan CORS + `SameSite=None` + `Secure`.
  - pastikan proxy/load balancer meneruskan header dan cookie.

### 6) Production Debug Checklist (Jika Login Gagal)

- Jika endpoint `https://<domain>/api/health` tidak 200:
  - cek reverse proxy (nginx) `proxy_pass` mengarah ke service api yang benar.
  - cek container `api` running dan port terbuka.
  - cek logs `api` (migration error, DB down, redis down).
- Jika `api/health` 200 tapi login gagal:
  - cek response `POST /api/auth/login` (401 vs 422 vs 500).
  - cek cookie `ppm_session` terset (domain/path/secure/samesite).
  - cek redis connectivity (session disimpan di redis).
  - reset admin via script setup admin yang pakai env.

### 7) Rollback

- Selalu bisa rollback dengan:
  - mengembalikan routing/proxy ke stack lama,
  - atau menjalankan FastAPI mode read-from-laravel (dual-DB) sementara.

## Output yang Diharapkan

- Endpoint inti berfungsi: `/api/health`, `/api/auth/*`, dan data module utama.
- Data di DB FastAPI konsisten (lookup terisi, relasi kontak terbentuk).
- Login sukses dari domain production.

