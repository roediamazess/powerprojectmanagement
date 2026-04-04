#!/bin/bash

# Level 4: Logika Prosedural - Deployment Docker (Produksi)
# Script ini digunakan untuk memastikan semua perubahan kode terbaru
# ter-deploy dengan benar ke dalam container Docker.

set -e

PROJECT_DIR="/opt/power-project-management/laravel-app"
if [ ! -d "$PROJECT_DIR" ]; then
    PROJECT_DIR="/home/ubuntu/power-project-management/laravel-app"
fi

cd "$PROJECT_DIR"

echo "## [DEPLOY] Memulai proses deployment di IP 43.153.211.40 ##"

# 1. Pastikan kode terbaru sudah ditarik (jika pakai git)
# git pull origin main

# 2. Rebuild image (memastikan perubahan Controller/Blade ikut terbawa)
echo "## [1/4] Rebuilding Docker Images... ##"
docker compose -f docker-compose.prod.yml build --no-cache

# 3. Restart container dengan image baru dan bersihkan volume build
echo "## [2/4] Restarting Containers & Cleaning Build Volumes... ##"
docker compose -f docker-compose.prod.yml down
docker volume rm -f laravel-app_public_build || true
docker compose -f docker-compose.prod.yml up -d

# 4. Bersihkan cache di dalam container app
echo "## [3/4] Clearing Laravel Caches... ##"
docker compose -f docker-compose.prod.yml exec -T app php artisan optimize:clear

# 5. Verifikasi status akhir
echo "## [4/4] Verifying Deployment... ##"
docker compose -f docker-compose.prod.yml ps

echo "## [SUCCESS] Deployment Selesai! ##"
