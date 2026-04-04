---
name: "pgsql-docker-maintenance"
description: "Maintains PostgreSQL in Docker (dump/restore, health, migrations). Invoke when migrating DB, restoring backups, or debugging DB connectivity."
---

# PostgreSQL (Docker) Maintenance

Skill ini untuk operasi database Postgres yang berjalan sebagai service `db` di Docker Compose.

## Kapan Dipakai

- Migrasi VPS, backup/restore DB, atau verifikasi data.
- Error koneksi DB di Laravel (`SQLSTATE`, `could not connect`, dsb).

## Healthcheck

```bash
docker compose -f laravel-app/docker-compose.prod.yml ps
docker compose -f laravel-app/docker-compose.prod.yml exec -T db pg_isready -U "${DB_USERNAME:-app}" -d "${DB_DATABASE:-app}"
```

## Dump DB (ke file lokal)

```bash
cd laravel-app
set -a; . ./.env; set +a
docker compose -f docker-compose.prod.yml exec -T db pg_dump -U "$DB_USERNAME" -d "$DB_DATABASE" | gzip > "db_${DB_DATABASE}_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
```

## Restore DB

```bash
cd laravel-app
set -a; . ./.env; set +a
gunzip -c /path/to/dump.sql.gz | docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USERNAME" -d "$DB_DATABASE"
```

## Migrations (di container app)

```bash
docker compose -f laravel-app/docker-compose.prod.yml exec -T app php artisan migrate:status
docker compose -f laravel-app/docker-compose.prod.yml exec -T app php artisan migrate --force
```

