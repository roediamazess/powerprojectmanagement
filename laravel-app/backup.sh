#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-all}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

compose_project="${COMPOSE_PROJECT:-laravel-app}"
compose_file="${COMPOSE_FILE:-${script_dir}/docker-compose.prod.yml}"

backup_root="${BACKUP_DIR:-${repo_root}/.backups/powerpro}"
retention_days_db="${RETENTION_DAYS_DB:-14}"
retention_days_files="${RETENTION_DAYS_FILES:-14}"

ts="$(date -u +%Y%m%dT%H%M%SZ)"

db_dir="${backup_root}/db"
files_dir="${backup_root}/files"
meta_dir="${backup_root}/meta"

mkdir -p "${db_dir}" "${files_dir}" "${meta_dir}"

compose() {
  docker compose -p "${compose_project}" -f "${compose_file}" "$@"
}

require_running() {
  local svc="$1"
  if [ -z "$(compose ps -q "${svc}" 2>/dev/null || true)" ]; then
    echo "Service '${svc}' tidak ditemukan atau belum dibuat (compose: ${compose_file})" >&2
    exit 1
  fi
  if [ "$(compose ps -q "${svc}" | wc -l | tr -d ' ')" = "0" ]; then
    echo "Service '${svc}' belum running" >&2
    exit 1
  fi
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  echo "sha256 tool tidak tersedia" >&2
  exit 1
}

backup_db() {
  require_running db
  local out="${db_dir}/db_${ts}.sql.gz"
  compose exec -T db sh -lc 'export PGPASSWORD="${POSTGRES_PASSWORD:-}"; pg_dump -U "${POSTGRES_USER:-app}" "${POSTGRES_DB:-app}"' \
    | gzip -c > "${out}"
  local sum
  sum="$(sha256_file "${out}")"
  printf '%s  %s\n' "${sum}" "$(basename "${out}")" >> "${meta_dir}/sha256_db_${ts}.txt"
  echo "${out}"
}

backup_storage() {
  require_running app
  local out="${files_dir}/storage_${ts}.tar.gz"
  compose exec -T app sh -lc 'tar -C /var/www/html -czf - storage/app' > "${out}"
  local sum
  sum="$(sha256_file "${out}")"
  printf '%s  %s\n' "${sum}" "$(basename "${out}")" >> "${meta_dir}/sha256_files_${ts}.txt"
  echo "${out}"
}

backup_public_branding() {
  require_running web
  local out="${files_dir}/public_branding_${ts}.tar.gz"
  compose exec -T web sh -lc 'tar -C /var/www/html -czf - public/favicon.png public/favicon.ico public/images/power-pro-logo-plain.png public/images/power-pro-logo.png' > "${out}"
  local sum
  sum="$(sha256_file "${out}")"
  printf '%s  %s\n' "${sum}" "$(basename "${out}")" >> "${meta_dir}/sha256_files_${ts}.txt"
  echo "${out}"
}

rotate() {
  find "${db_dir}" -type f -name 'db_*.sql.gz' -mtime +"${retention_days_db}" -delete 2>/dev/null || true
  find "${files_dir}" -type f -name 'storage_*.tar.gz' -mtime +"${retention_days_files}" -delete 2>/dev/null || true
  find "${files_dir}" -type f -name 'public_branding_*.tar.gz' -mtime +"${retention_days_files}" -delete 2>/dev/null || true
  find "${meta_dir}" -type f -name 'sha256_*' -mtime +"${retention_days_files}" -delete 2>/dev/null || true
}



upload_drive() {
  if ! command -v rclone >/dev/null 2>&1; then
    echo "rclone belum terpasang. Install dulu: https://rclone.org/install/" >&2
    return 1
  fi
  local remote="${RCLONE_REMOTE:-gdrive}"
  local path="${RCLONE_PATH:-powerpro}"
  local dest="${remote}:${path}"
  echo "Mengunggah backup ke ${dest} ..."
  rclone sync -P "${backup_root}" "${dest}" --create-empty-src-dirs
}
print_cron() {
  echo "Cron harian (02:10):"
  echo "10 2 * * * cd ${repo_root} && /usr/bin/env bash ${script_dir}/backup.sh all >> ${backup_root}/backup.log 2>&1"
  echo
  echo "Cron mingguan (Minggu 03:10):"
  echo "10 3 * * 0 cd ${repo_root} && RETENTION_DAYS_DB=60 RETENTION_DAYS_FILES=60 /usr/bin/env bash ${script_dir}/backup.sh all >> ${backup_root}/backup.log 2>&1"
}

case "${cmd}" in
  db)
    backup_db >/dev/null
    rotate
    ;;
  files)
    backup_storage >/dev/null
    backup_public_branding >/dev/null
    rotate
    ;;
  all)
    backup_db >/dev/null
    backup_storage >/dev/null
    backup_public_branding >/dev/null
    rotate
    if [ "${DO_UPLOAD:-0}" = "1" ]; then upload_drive || true; fi
    ;;
  cron)
    print_cron
    ;;
  upload)
    upload_drive
    ;;
  *)
    echo "Usage: ${0} [db|files|all|cron]" >&2
    echo "Env: BACKUP_DIR, COMPOSE_PROJECT, COMPOSE_FILE, RETENTION_DAYS_DB, RETENTION_DAYS_FILES" >&2
    exit 1
    ;;
 esac
