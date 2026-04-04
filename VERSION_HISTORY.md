# Version History — Power Project Management

Format versi: `v1.YYMM.patch`


## v1.2603.7 — 2026-03-31

### Added
- Dashboard Partners: fitur drilldown interaktif (double-click segmen chart) untuk melihat detail list partner.
- Theme: sistem sinkronisasi tema lintas komponen via MutationObserver + custom event `themechange`.
- Deployment: workflow deployment otomatis untuk environment Docker (rebuild + volume sync).
- Knowledge Base: dokumentasi arsitektur sistem dan panduan deployment untuk model AI.

**Referensi perubahan:**
- Drilldown UI: `resources/js/Pages/Dashboard/Partners.jsx`
- Drilldown controller: `app/Http/Controllers/DashboardPartnersController.php`
- Theme logic: `resources/js/Layouts/AuthenticatedLayout.jsx`, `resources/js/Pages/Dashboard/Partners.jsx`
- Deployment: `.agent/workflows/deploy.md`, `.gemini/antigravity/knowledge/powerpro-deployment/`

### Fixed
- Theme: perbaiki bug toggle icon yang tidak berubah (Moon/Sun icon nyangkut di mode dark).
- Theme: perbaiki background modal drilldown yang tetap gelap saat mode light.
- Theme: perbaiki bug `applySettingsOptions` yang return early jika plugin jQuery belum load.
- UI: sinkronisasi warna border dan header tabel modal agar adaptif terhadap tema.

**Referensi perubahan:**
- Toggle fix: `resources/js/Layouts/AuthenticatedLayout.jsx`
- Modal theme fix: `resources/css/app.css`, `resources/js/Pages/Dashboard/Partners.jsx`
- Layout core: `resources/js/Layouts/AuthenticatedLayout.jsx`

### Changed
- Partners Dashboard: refactor komponen untuk memakai inline-style yang dikontrol state React demi reliabilitas tema 100%.
- Modal: update selektor CSS `.modal-content` untuk mendukung sinkronisasi tema manual.
- Version History: update ke v1.2603.7 dengan rangkuman perbaikan tema dan fitur dashboard.

**Referensi perubahan:**
- Partners refactor: `resources/js/Pages/Dashboard/Partners.jsx`
- CSS update: `resources/css/app.css`
- Authenticated layout: `resources/js/Layouts/AuthenticatedLayout.jsx`

---

## v1.2603.6 — 2026-03-26

### Added
- Branding: favicon diganti ke logo polos dan konsisten di seluruh halaman.
- Branding: cache-buster untuk logo (`/images/power-pro-logo-plain.png?v=20260326`) agar update terlihat tanpa konflik cache.

**Referensi perubahan:**
- Favicon: `public/favicon.png`
- Login logo: `resources/js/Layouts/GuestLayout.jsx`
- Header logo: `resources/js/Layouts/AuthenticatedLayout.jsx`

### Fixed
- Auth: perbaiki 405 saat logout dengan mengganti route ke POST dan redirect yang benar.
- Login: perbaiki halaman blank akibat import chunk Vite yang 404 (sinkronisasi build & manifest produksi).
- Projects: perbaiki validasi assignment PIC yang terlalu ketat (nullable).
- Bootstrap: bersihkan duplikasi konfigurasi `redirectGuestsTo` pada bootstrap middleware.

**Referensi perubahan:**
- Routes logout: `routes/auth.php`
- Controller logout: `app/Http/Controllers/Auth/AuthenticatedSessionController.php`
- Build & manifest: `docker-compose.prod.yml`, `docker/php/entrypoint.sh`, `docker/nginx/Dockerfile`
- Projects controller: `app/Http/Controllers/Tables/ProjectsController.php`
- Bootstrap: `bootstrap/app.php`

### Changed
- Login: hilangkan teks “Sign up” dan heading di bawah logo agar tampilan lebih minimal.
- Header aplikasi: ganti ikon SVG menjadi logo PNG polos yang sama dengan halaman login.
- Branding: konsisten memakai “Power Project Management” di seluruh area.

**Referensi perubahan:**
- Login layout: `resources/js/Layouts/GuestLayout.jsx`
- Authenticated layout: `resources/js/Layouts/AuthenticatedLayout.jsx`
- Dashboard copy: `resources/js/Pages/Dashboard.jsx`

---

## v1.2603.5 — 2026-03-24

### Added
- Time Boxing: header kolom bisa dibuka (popup) untuk Sort + Filter.
- Time Boxing: filter multi-select untuk Type, Priority, Partner, dan Status.
- Time Boxing: segmented status All Status | Active Status | Completed (default: Active Status).
- Time Boxing: picker Partner & Project berbasis popup (Partner: Active only; Project: bukan Done/Rejected).
- Time Boxing: dukungan filter rentang Due Date.
- Endpoint options Time Boxing untuk mengambil opsi filter berdasarkan tab status.
- Import Time Boxing dari XLSX via artisan command (lookup Partner CNC + auto-create Type).
- Version History: Referensi perubahan diblur untuk selain Administrator/Management.
- Projects: header kolom Sort + Filter (Partner, Type, Start Date, Status) + ringkasan filter aktif.
- Projects: segmented status All | Running (default) | Planning (Tentative+Scheduled) | Document | Document Check | Done | Rejected.
- Audit Logs: header kolom Sort + Filter (Module, Action, Actor, Time) + filter range tanggal.
- Audit Logs: ringkasan filter aktif (Time | Module | Action | Actor) + tampilan Changed Fields (Before vs After).
- Routing pendek aktif untuk /partners, /projects, /time-boxing, /audit-logs (CRUD dan navigasi).

**Referensi perubahan:**
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Projects controller: `app/Http/Controllers/Tables/ProjectsController.php`
- Audit Logs UI: `resources/js/Pages/Tables/AuditLogs/Index.jsx`
- Audit Logs controller: `app/Http/Controllers/Tables/AuditLogsController.php`
- Routing: `routes/web.php`

### Fixed
- Projects: perbaiki crash ringkasan filter karena deklarasi fungsi (hoisting).
- Navigasi: pastikan semua route() relative ke origin aktif agar tidak pindah domain.
- Time Boxing (test env): fallback penomoran no untuk non-PostgreSQL.

**Referensi perubahan:**
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Ziggy origin: `resources/js/app.jsx`
- TimeBoxing controller: `app/Http/Controllers/Tables/TimeBoxingsController.php`

### Changed
- Projects: hapus Search (server) + tombol Apply/Reset; label End → End Date.
- Audit Logs: sembunyikan Meta dan blok Before/After mentah; hanya tampilkan Changed Fields; sembunyikan field attachment/file/photo/avatar.
- Semua form & redirect CRUD memakai route pendek (/partners, /projects, /time-boxing, /audit-logs).

**Referensi perubahan:**
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Audit Logs UI: `resources/js/Pages/Tables/AuditLogs/Index.jsx`
- Layouts: `resources/js/Layouts/AuthenticatedLayout.jsx`
- Routing: `routes/web.php`

---

## v1.2603.4 — 2026-03-23

### Added
- Tambahkan upload foto profile di halaman `Profile` dan tampilkan avatar di header/sidebar.
- Tambahkan kompresi foto di browser (resize + JPEG) sebelum upload agar ukuran hemat.
- Tambahkan import data Partners dari XLSX dan auto-link ke `Tables > Partner Setup` / `Project Setup`.
- Tambahkan segmented filter status Partners: `Active | Freeze | Inactive | All Status` (default: Active).
- Tambahkan index full-text (GIN) untuk mempercepat search di Audit Logs (PostgreSQL).
- Tambahkan coverage test untuk akses halaman Tables (Admin) dan upload profile photo.

**Referensi perubahan:**
- Profile UI: `resources/js/Pages/Profile/Partials/UpdateProfileInformationForm.jsx`
- Layout avatar: `resources/js/Layouts/AuthenticatedLayout.jsx`
- Profile endpoints: `app/Http/Controllers/ProfileController.php`, `routes/web.php`
- Partners import: `routes/console.php`, `app/Services/PartnersXlsxImportService.php`, `app/Support/XlsxReader.php`
- Partners status filter: `app/Http/Controllers/Tables/PartnersController.php`, `resources/js/Pages/Tables/Partners/Index.jsx`
- Audit index: `database/migrations/2026_03_23_000001_add_audit_logs_full_text_index.php`
- Tests: `tests/Feature/TablesAdminAccessTest.php`, `tests/Feature/ProfilePhotoTest.php`

### Fixed
- Fix 403 permission untuk role Administrator di halaman Tables (Time Boxing/Setup, Project Setup, dll).
- Fix 413 Request Entity Too Large saat upload photo dengan menyesuaikan limit Nginx.
- Fix pencarian data Partners lintas halaman: Search di header sekarang melakukan server search (reset pagination otomatis).
- Fix parsing tanggal `dd Mmm yy` pada perhitungan durasi di halaman Projects.
- Fix kompatibilitas migration saat test (SQLite) untuk query PostgreSQL sequence.

**Referensi perubahan:**
- Routes middleware: `routes/web.php`
- Permission seeding: `app/Http/Middleware/EnsureCorePermissions.php`, `app/Support/PermissionCatalog.php`
- Nginx: `docker/nginx/default.conf`
- Partners search: `resources/js/Layouts/AuthenticatedLayout.jsx`, `resources/js/Pages/Tables/Partners/Index.jsx`, `app/Http/Controllers/Tables/PartnersController.php`
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Migrations: `database/migrations/2026_03_20_000008_create_time_boxings_table.php`, `2026_03_20_000010_add_no_to_projects_table.php`

### Changed
- Standarisasi input tanggal diselesaikan agar seluruh halaman Tables memakai komponen global `DatePickerInput` (format `dd Mmm yy`).
- Filter Info Date di Time Boxing tidak lagi bergantung pada datepicker jQuery; memakai komponen global.
- Pola middleware akses Tables diperkuat: Administrator dapat akses meski permission belum tersinkron.
- Branding title aplikasi distandarkan menjadi `Power Project Management` (tanpa suffix `Laravel`).
- Partners: hapus Search (server) + tombol Apply/Reset karena Search header sudah cukup.

**Referensi perubahan:**
- Date component: `resources/js/Components/DatePickerInput.jsx`
- Tables pages: `resources/js/Pages/Tables/*/Index.jsx`
- App title: `resources/js/app.jsx`, `resources/views/app.blade.php`
- Partners UI: `resources/js/Pages/Tables/Partners/Index.jsx`
- Routes: `routes/web.php`

---

## v1.2603.3 — 2026-03-20

### Added
- Tambahkan module `Projects` (CRUD) sejajar dengan Partners di sidebar.
- Tambahkan `Tables > Project Setup` untuk mengelola option `Type` dan `Status` (Active/Inactive).
- Tambahkan dukungan multi PIC per project dengan periode berbeda (table `project_pic_assignments`).

**Referensi perubahan:**
- Routes: `routes/web.php`
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Project Setup UI: `resources/js/Pages/Tables/ProjectSetup/Index.jsx`
- Projects controller: `app/Http/Controllers/Tables/ProjectsController.php`
- Project Setup controller: `app/Http/Controllers/Tables/ProjectSetupController.php`
- Migrations: `database/migrations/2026_03_19_000006_create_project_setup_options_table.php`, `2026_03_19_000007_create_projects_table.php`, `2026_03_20_000001_create_project_pic_assignments_table.php`

### Fixed
- Validasi backend: periode PIC tidak boleh di luar periode Project.
- Validasi backend: jika PIC dipilih, Start/End pada baris PIC wajib diisi.

**Referensi perubahan:**
- Validation: `app/Http/Controllers/Tables/ProjectsController.php`

### Changed
- Model data Projects: PIC utama bergeser menjadi ringkasan dari daftar PIC-periode (multi-PIC).
- UI Projects: input PIC menjadi tabel baris dinamis (Add/Remove) agar history periode lebih jelas.
- Dokumentasi perubahan dirapikan melalui `CHANGELOG.md`.

**Referensi perubahan:**
- Projects UI: `resources/js/Pages/Tables/Projects/Index.jsx`
- Changelog: `CHANGELOG.md`

---

## v1.2603.2 — 2026-03-19

### Auth & Navigation
- Fix post-login halaman blank pada flow Inertia (redirect/login).
- Tambah fallback hard redirect setelah login sukses agar tidak perlu reload manual.

**Referensi perubahan:**
- Backend login: `app/Http/Controllers/Auth/AuthenticatedSessionController.php`
- Frontend login: `resources/js/Pages/Auth/Login.jsx`

### User Management (Tables)
- Tambah menu sidebar: `Tables > User Management`.
- Buat halaman list user (langsung tampil) + modal `New/Edit`.
- CRUD user: create & update via form modal (password optional saat edit).
- Tampilkan kolom: ID, Name, Full Name, Email, Start Work, Birthday, Tier, Status, Role.

**Referensi perubahan:**
- Routes: `routes/web.php`
- Controller: `app/Http/Controllers/Tables/UserManagementController.php`
- UI Page: `resources/js/Pages/Tables/UserManagement/Index.jsx`
- Sidebar: `resources/js/Layouts/AuthenticatedLayout.jsx`

### Schema & Data
- Extend tabel `users`: `full_name`, `start_work`, `birthday`, `tier`, `status`.
- Default status: `Active`.
- Import data user PowerPro ke PostgreSQL (idempotent, match by email).
- Set password awal semua user import: `pps88` (hashed), user bisa ganti sendiri.

**Referensi perubahan:**
- Migrations: `database/migrations/2026_03_19_000000_add_user_management_fields_to_users_table.php`
- Migrations: `database/migrations/2026_03_19_000001_add_tier_status_to_users_table.php`
- Seeder import: `database/seeders/PowerProUserImportSeeder.php`
- Model: `app/Models/User.php`

### Roles & Access
- Role options: `Administrator`, `Management`, `Admin Officer`, `User`, `Partner`.
- Assign role ke user via Spatie Permission (syncRoles).
- Seed roles default untuk memastikan opsi selalu tersedia.

**Referensi perubahan:**
- Seeder roles: `database/seeders/DatabaseSeeder.php`
- Spatie config: `config/permission.php`

### UI/UX Consistency
- Form create/edit dipindah ke modal agar list lebih clean.
- Standarisasi urutan tombol modal: action (Create/Update/Delete) di kiri, Cancel di kanan.
- Tambah Version History modal: versi di footer bisa diklik.
- Tampilan Version History mengikuti theme (primary/body/card) dari settings gear.

**Referensi perubahan:**
- User modal: `resources/js/Pages/Tables/UserManagement/Index.jsx`
- Profile delete modal: `resources/js/Pages/Profile/Partials/DeleteUserForm.jsx`
- Project rules: `.trae/rules/project_rules.md`
- Layout: `resources/js/Layouts/AuthenticatedLayout.jsx`
- Theme settings: `public/js/settings.js`
- Theme UI: `public/css/style.css`

### Deployment & Assets
- Fix blank page saat reload `/dashboard` karena `public/build` tidak sinkron antara container app dan web.
- Gunakan shared volume `public/build` agar manifest + assets selalu match.

**Referensi perubahan:**
- Compose: `docker-compose.prod.yml`
- PHP image: `docker/php/Dockerfile`
- Nginx image: `docker/nginx/Dockerfile`
- Entrypoint sync: `docker/php/entrypoint.sh`

### Access Control (UI)
- Pindahkan pengaturan permission role dari bawah halaman menjadi tombol `User Rights` (popup) di User Management.

**Referensi perubahan:**
- UI: `resources/js/Pages/Tables/UserManagement/Index.jsx`

### Smart Search
- Search bar header sekarang memfilter data pada halaman aktif (bukan global), dan reset otomatis saat pindah page.
- Implement filtering di User Management, Partners, dan Partner Setup.

**Referensi perubahan:**
- Layout: `resources/js/Layouts/AuthenticatedLayout.jsx`
- User Mgmt: `resources/js/Pages/Tables/UserManagement/Index.jsx`
- Partners: `resources/js/Pages/Tables/Partners/Index.jsx`
- Partner Setup: `resources/js/Pages/Tables/PartnerSetup/Index.jsx`

### Partner Setup Rules
- Tambah status `Active/Inactive` pada Partner Setup options (default: Active).
- Dropdown setup di form Partners hanya menampilkan option `Active` (inactive tetap terlihat jika sudah terpilih, tapi disabled).
- Cegah delete (dan ganti nama/category) option yang sudah dipakai data Partners; arahkan untuk set `Inactive` saja.
- Fix error 500 Partner Setup: define `$usedValues` saat render list.

**Referensi perubahan:**
- Migration: `database/migrations/2026_03_19_000005_add_status_to_partner_setup_options_table.php`
- Controller: `app/Http/Controllers/Tables/PartnerSetupController.php`
- Controller: `app/Http/Controllers/Tables/PartnersController.php`
- UI: `resources/js/Pages/Tables/PartnerSetup/Index.jsx`
- UI: `resources/js/Pages/Tables/Partners/Index.jsx`

---

## v1.2603.1 — 2026-03-18

### Branding & UI
- Logo brand (ikon) diganti ke logo baru (4 lingkaran warna).
- Brand title diganti menjadi teks:
  - Normal: `Power Project Management`
  - Mode sidebar collapse: `PPM`
- Tombol settings (cog) di sidebar kanan dirapikan agar ikon rata tengah.

**Referensi perubahan:**
- Next (legacy): `app/page.tsx`
- Laravel/Inertia: `laravel-app/resources/js/Layouts/AuthenticatedLayout.jsx`
- CSS template: `public/css/style.css`, `laravel-app/public/css/style.css`

### Footer
- Footer diseragamkan dan dibuat rata tengah (2 baris):
  - `© 2026 — Where Insights Drive Action`
  - `v1.2603.1`

**Referensi perubahan:**
- Template static HTML: `public/*.html`
- Template untuk Laravel route `/template/...`: `laravel-app/resources/template-pages/*.html`
- Next (legacy): `app/page.tsx`
- Laravel/Inertia: `laravel-app/resources/js/Layouts/AuthenticatedLayout.jsx`

### Stabilitas & Fix
- Menghapus “hack replace footer” yang sebelumnya menyuntik teks via JS/CSS.
  - `public/js/dlabnav-init.js`
  - `public/css/style.css`
  - `laravel-app/public/js/dlabnav-init.js`
  - `laravel-app/public/css/style.css`
- Memperbaiki error Next dev (port 3000) yang menyebabkan halaman “muter-muter” (compile error `app/page.tsx`).
- Menstabilkan Next dev container di Windows with adding volume `.next` (avoid error lockfile).
  - `docker-compose.yml`

### Backup & Restore
- Menambahkan mekanisme backup tanpa menimpa backup lama (timestamped archive) + verifikasi restore.
- Menambahkan log backup SHA256.
- Menambahkan script:
  - `backup.ps1`
  - `restore.ps1`
- Menambahkan dokumentasi:
  - `.backups/README.md`
  - `.backups/backup-log.csv`

### Baseline awal
- Blueprint proyek berasal dari OpenClaw.
- Struktur aplikasi rekomendasi:
  - Next.js (legacy UI/template) di root repo.
  - Laravel + Inertia (React) di folder `laravel-app/`.
