# Changelog

## v1.2603.2 (2026-03-19)

### Deployment & Assets
- Fix blank page saat reload `/dashboard` karena `public/build` tidak sinkron antara container app dan web.
- Gunakan shared volume `public/build` agar manifest + assets selalu match.

### Access Control (UI)
- Pindahkan pengaturan permission role menjadi tombol `User Rights` (popup) di User Management.

### Smart Search
- Search bar header memfilter data pada halaman aktif (bukan global), dan reset otomatis saat pindah page.
- Implement filtering di User Management, Partners, dan Partner Setup.

### Partner Setup Rules
- Tambah status `Active/Inactive` pada Partner Setup options (default: Active).
- Dropdown setup di form Partners hanya menampilkan option `Active` (inactive tetap terlihat jika sudah terpilih, tapi disabled).
- Cegah delete (dan ganti nama/category) option yang sudah dipakai data Partners; arahkan untuk set `Inactive` saja.
- Fix error 500 Partner Setup: define `$usedValues` saat render list.

---

Catatan: versi aplikasi tetap **v1.2603.2** (tidak bump) dan log perubahan terbaru dicatat di versi ini.
