---
name: "skills-project-router"
description: "Enforces project-wide rules and uses references/examples/scripts for consistent features. Invoke for any feature work, queries, migrations, or deployments."
---

# Skills Project Router (5 Level)

Skill ini adalah “router utama” untuk memastikan AI konsisten dan akurat saat mengerjakan repo ini. Gunakan sebagai aturan induk; skill lain menjadi pendukung eksekusi.

## Dispatch Skill (Kapan Memanggil Skill Lain)

- Deploy/rebuild/troubleshoot Docker Compose: gunakan `laravel-docker-deploy`.
- Asset `/build/*` (CSS/JS hilang, manifest mismatch, cache 404): gunakan `inertia-vite-assets`.
- Cloudflare (nameserver, DNS, SSL mode, cache): gunakan `cloudflare-dns-ssl`.
- “Docker-only” cleanup (hapus dependency host path, cert mount, UI eksternal): gunakan `docker-only-audit`.
- Office Agent (UI/route, SSE stream, polling, redirect legacy): gunakan `office-agent-ops`.
- Postgres dalam Docker (dump/restore/health/migrate): gunakan `pgsql-docker-maintenance`.

## Level 1: Router Dasar (Instruksi Langsung)

Aturan berikut wajib diterapkan di setiap perubahan fitur/query:

- Multi-tenancy: setiap query dan endpoint yang akses data tenant harus memfilter `tenant_id` dan tidak boleh bocor lintas tenant.
- Roles & Permissions: implementasi akses menggunakan Spatie Permission (role/permission). Jangan hardcode role tanpa mengikuti pola Spatie.
- Audit logging: setiap aksi create/update/delete penting wajib tercatat (minimal module, action, actor, payload ringkas, timestamp).

Jika ada perubahan yang berpotensi melanggar 3 aturan ini, hentikan dan perbaiki sampai aman.

### Implementasi Level 1 (Konvensi Repo Ini)

- Tenant context:
  - Tenant diset oleh middleware `EnsureTenantContext` (binding `app('tenant')`) berdasarkan `user.tenant_id`.
  - Model yang punya kolom `tenant_id` wajib menggunakan global scope tenancy (gunakan trait `App\Models\Concerns\BelongsToTenant`).
  - Saat membuat tabel baru yang bersifat tenant-scoped, wajib tambahkan `tenant_id` (+ index + FK sesuai kebutuhan).
- Roles & permissions:
  - Gunakan middleware route `role_or_permission:Administrator|<permission-key>` sebagai pola default.
  - Permission key mengacu ke `App\Support\PermissionCatalog` (tambahkan permission baru di sana jika menambah modul/aksi baru).
  - Untuk admin super (mis. internal), tetap gunakan Spatie middleware/policy; jangan bypass check.
- Audit logging:
  - Gunakan `App\Models\AuditLog::record($request, $action, $modelType, $modelId, $before, $after, $metaExtra)` pada operasi mutasi data.
  - `before` dan `after` wajib ringkas (array) agar tidak menyimpan data sensitif.

## Level 2: Pemanfaatan Aset (File Referensi)

Jangan menuliskan ringkasan besar di skill ini. Gunakan file referensi jika tersedia:

- Baca `resources/db_schema.txt` untuk relasi DB/tabel dan aturan data.
- Baca `resources/sidebar.txt` untuk navigasi sidebar dan penamaan menu.
- Baca `resources/project_overview.txt` untuk gambaran proyek dan boundary tiap modul.

Jika file belum ada, gunakan eksplorasi codebase (migrations/models/routes/pages) sebagai sumber kebenaran.

## Level 3: Belajar dengan Contoh (Few-shot)

Saat membuat modul baru, ikuti contoh gaya yang ada di folder `examples/` (jika tersedia):

- `examples/controller.php` (controller style, validation, tenancy, audit)
- `examples/routes.php` (route grouping + middleware)
- `examples/page.jsx` (Inertia page style, UI conventions)

Jika folder `examples/` belum ada, tiru pola dari implementasi yang sudah ada di repo (controller + Inertia pages terdekat).

## Level 4: Logika Prosedural (Eksekusi Script)

Untuk tugas berulang, gunakan script (jika tersedia) agar hasil konsisten:

- Build/Up Docker Compose (prod/local)
- Backup/restore DB dan storage volume
- Rebuild asset (Vite)

Jika script belum ada, gunakan perintah docker compose yang sudah menjadi standar di repo.

## Level 5: Sang Arsitek (Orkestrasi Penuh)

Saat user minta modul besar (mis. “Modul Produk”), alur wajib:

1) Terapkan Level 1 (tenant_id, Spatie, audit) di desain dan implementasi.
2) Ambil acuan dari Level 2 (schema/sidebar/overview) sebelum menulis kode.
3) Tiru gaya Level 3 (examples/pola existing) untuk controller/routes/pages.
4) Jalankan Level 4 (build/test/deploy) untuk memastikan aplikasi benar-benar jalan.
5) Verifikasi ulang: tidak ada kebocoran tenant, akses sudah sesuai role/permission, audit tercatat.

## Batasan Repo (Monorepo)

- Aplikasi utama: `laravel-app/` (Laravel 12 + Inertia React).
- Root repo berisi Next.js legacy; jangan ubah bagian Next.js kecuali user minta eksplisit.
