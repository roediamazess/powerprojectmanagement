---
name: "power-pro-architect"
description: "Arsitek utama proyek Power Pro. Gunakan setiap kali membuat fitur baru, modifikasi query, atau manajemen server/deployment."
---

# Power Pro Architect Skill

Skill ini adalah orkestrator utama untuk proyek Power Pro Management. AI harus mengikuti 5 level hierarki berikut untuk setiap tugas:

## Level 1: Aturan Dasar (Router Dasar)
- **Tenant Filtering**: Setiap query ke database WAJIB menyertakan filter `tenant_id` dari user yang sedang login.
- **Roles & Permissions**: Implementasi hak akses WAJIB menggunakan Spatie Laravel Permission.
- **Audit Logging**: Setiap aksi `create`, `update`, dan `delete` WAJIB dicatat menggunakan `AuditLog::record`.

## Level 2: Pemanfaatan Aset (File Referensi)
- Baca [db_schema.txt](file:///home/ubuntu/power-project-management/laravel-app/resources/db_schema.txt) untuk memahami relasi tabel dan konvensi kolom sebelum membuat migrasi atau model baru.
- Gunakan [sidebar.txt](file:///home/ubuntu/power-project-management/laravel-app/resources/sidebar.txt) untuk referensi navigasi UI.

## Level 3: Belajar dengan Contoh (Few-Shot)
- Lihat folder [examples/](file:///home/ubuntu/power-project-management/laravel-app/examples/) untuk meniru gaya koding (coding style) Controller, Model, dan Inertia Pages yang ideal.

## Level 4: Logika Prosedural (Eksekusi Script)
- Gunakan script di folder `scripts/` untuk tugas operasional.
- **Deployment**: Jalankan [deploy_docker.sh](file:///home/ubuntu/power-project-management/laravel-app/scripts/deploy_docker.sh) setiap kali ada perubahan pada Controller, Blade, atau Konfigurasi untuk memastikan perubahan ter-deploy ke dalam container di IP 43.153.211.40.
- **Backup**: Jalankan [db_backup.sh](file:///home/ubuntu/power-project-management/laravel-app/scripts/db_backup.sh) jika user meminta backup database.

## Level 5: Sang Arsitek (Orkestrasi)
- Saat membangun modul baru:
  1. Buat kerangka file (Level 4).
  2. Gunakan referensi schema (Level 2).
  3. Tiru gaya koding dari folder examples (Level 3).
  4. Pastikan tenant filtering dan audit logging terimplementasi (Level 1).
