#!/bin/bash
set -e

echo "🚀 Memulai Deployment Power Project Management (FastAPI + Vue3) ke Production..."

cd "$(dirname "$0")/.."

echo "Mengeksekusi dari file sistem lokal (mengabaikan Git pull untuk menjaga uncommitted code)..."

echo "🏗️ Membangun dan me-recreate kontainer Docker (Backend API, Celery, Redis, Database, dan Vue3 Frontend)..."
cd infra
docker compose -f docker-compose.rewrite.prod.yml up -d --build

echo "🧹 Membersihkan unused Docker images..."
docker image prune -f

echo "✅ Deploy sukses! Stack baru (FastAPI & Vue3) saat ini sedang berjalan."
echo "🌐 Akses web di: http://localhost:8080 (atau reverse proxy Nginx utama Anda)"
echo "📡 Cek log API: docker compose -f docker-compose.rewrite.prod.yml logs -f api"
