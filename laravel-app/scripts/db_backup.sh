#!/bin/bash

# Level 4: Logika Prosedural (Eksekusi Script)
# Script untuk backup database PostgreSQL (production)
# Penggunaan: bash scripts/db_backup.sh

# Load ENV variables
source .env

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="storage/app/backups"
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"

mkdir -p $BACKUP_DIR

echo "## Memulai backup database: ${DB_DATABASE} ##"

# Jalankan pg_dump via Docker (jika pakai docker)
# atau langsung jika di host
if [ -f "docker-compose.prod.yml" ]; then
    docker compose -f docker-compose.prod.yml exec -T db pg_dump -U ${DB_USERNAME} ${DB_DATABASE} | gzip > $BACKUP_FILE
else
    pg_dump -U ${DB_USERNAME} ${DB_DATABASE} | gzip > $BACKUP_FILE
fi

if [ $? -eq 0 ]; then
    echo "## Backup BERHASIL: ${BACKUP_FILE} ##"
    # Tambahkan audit log manual atau via CLI di sini jika perlu
else
    echo "## Backup GAGAL! ##"
    exit 1
fi
