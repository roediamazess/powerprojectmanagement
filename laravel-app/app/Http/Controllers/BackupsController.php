<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Symfony\Component\Process\Process;
use App\Models\AuditLog;

class BackupsController extends Controller
{
    private function parseStatusFile(?string $content): array
    {
        $progress = 0;
        $done = false;
        $message = '';
        $error = '';

        foreach (preg_split("/\r?\n/", (string) $content) as $line) {
            $line = trim((string) $line);
            if ($line === '' || !str_contains($line, '=')) continue;
            [$k, $v] = explode('=', $line, 2);
            $k = trim($k);
            $v = trim($v);
            if ($k === 'progress') $progress = (int) $v;
            if ($k === 'done') $done = $v === '1';
            if ($k === 'message') $message = $v;
            if ($k === 'error') $error = $v;
        }

        if ($progress < 0) $progress = 0;
        if ($progress > 100) $progress = 100;

        return [
            'progress' => $progress,
            'done' => $done,
            'message' => $message,
            'error' => $error,
        ];
    }

    public function index()
    {
        $root = env('BACKUP_DIR') ?: storage_path('backup/manual');
        $dbDir = $root.'/db';
        $filesDir = $root.'/files';

        $list = [];
        foreach ([['dir'=>$dbDir,'type'=>'db','ext'=>'.sql.gz'],['dir'=>$filesDir,'type'=>'files','ext'=>'.tar.gz']] as $spec) {
            if (is_dir($spec['dir'])) {
                foreach (glob($spec['dir'].'/*'.$spec['ext']) as $f) {
                    $ts = date('c', filemtime($f));
                    $list[] = [
                        'name' => basename($f),
                        'path' => $f,
                        'size' => filesize($f),
                        'mtime' => $ts,
                        'type' => $spec['type'],
                    ];
                }
            }
        }
        usort($list, function($a,$b){return strcmp($b['mtime'],$a['mtime']);});
        $latest = array_slice($list, 0, 50);

        return Inertia::render('Backups/Index', [
            'root' => $root,
            'items' => $latest,
        ]);
    }

    public function run(Request $request)
    {
        $root = env('BACKUP_DIR') ?: storage_path('backup/manual');
        $remote = env('RCLONE_REMOTE', 'gdrive');
        $path = env('RCLONE_PATH', 'powerpro/manual_backups');

        $metaDir = rtrim($root, '/').'/meta';
        if (!is_dir($metaDir)) {
            mkdir($metaDir, 0775, true);
        }
        if (!is_dir($metaDir) || !is_writable($metaDir)) {
            return response()->json([
                'runId' => null,
                'alreadyRunning' => false,
                'error' => 'Server tidak bisa menulis ke folder backup (permission).',
            ], 500);
        }

        $lockDir = rtrim($root, '/').'/.manual_backup_lock';
        if (is_dir($lockDir)) {
            $existingRunId = @trim((string) @file_get_contents($lockDir.'/run_id'));
            if ($existingRunId === '') {
                @unlink($lockDir.'/run_id');
                @rmdir($lockDir);
                if (is_dir($lockDir)) {
                    return response()->json([
                        'runId' => null,
                        'alreadyRunning' => false,
                        'error' => 'Lock backup sebelumnya terdeteksi tetapi tidak valid. Silakan refresh halaman lalu coba lagi.',
                    ], 409);
                }
            }
            if ($existingRunId !== '') {
                $existingStatus = rtrim($metaDir, '/')."/manual_status_{$existingRunId}.txt";
                $content = is_file($existingStatus) ? File::get($existingStatus) : null;
                $parsed = $this->parseStatusFile($content);
                $isDone = (bool) ($parsed['done'] ?? false);
                if ($isDone) {
                    @unlink($lockDir.'/run_id');
                    @rmdir($lockDir);
                    $existingRunId = '';
                }
            }

            if (is_dir($lockDir)) {
                $age = time() - (int) @filemtime($lockDir);
                if ($age > 60 * 60) {
                    @unlink($lockDir.'/run_id');
                    @rmdir($lockDir);
                    $existingRunId = '';
                }
            }

            if (is_dir($lockDir)) {
            $payload = [
                'runId' => $existingRunId !== '' ? $existingRunId : null,
                'alreadyRunning' => true,
            ];
            return response()->json($payload);
            }
        }

        $runId = gmdate('Ymd\THis\Z').'-'.Str::lower(Str::random(8));
        $statusFile = rtrim($metaDir, '/')."/manual_status_{$runId}.txt";
        $written = file_put_contents($statusFile, "progress=1\nmessage=Menjalankan proses backup...\ndone=0\nerror=\n");
        if ($written === false) {
            return response()->json([
                'runId' => null,
                'alreadyRunning' => false,
                'error' => 'Server tidak bisa membuat file status backup (permission).',
            ], 500);
        }

        AuditLog::record($request, 'backups.manual.run', 'backups', $runId, [], [], [
            'backup_dir' => $root,
            'rclone' => [
                'remote' => $remote,
                'path' => $path,
            ],
        ]);

        $script = <<<'BASH'
set -euo pipefail

backup_root="${BACKUP_DIR:?BACKUP_DIR required}"
remote="${RCLONE_REMOTE:-gdrive}"
path="${RCLONE_PATH:-powerpro}"
run_id="${RUN_ID:?RUN_ID required}"
status_file="${STATUS_FILE:?STATUS_FILE required}"

update_status() {
  local p="$1"
  local msg="$2"
  printf "progress=%s\nmessage=%s\ndone=0\nerror=\n" "${p}" "${msg}" > "${status_file}"
}

fail_status() {
  local msg="${1:-Gagal}"
  printf "progress=100\nmessage=%s\ndone=1\nerror=%s\n" "Backup gagal" "${msg}" > "${status_file}"
}

trap 'cmd="${BASH_COMMAND%% *}"; fail_status "Terjadi error saat proses backup (${cmd})"; exit 1' ERR

cfg_src="${RCLONE_CONFIG_FILE:-/etc/rclone/rclone.conf}"
cfg="/tmp/rclone_${run_id}.conf"
if [ ! -f "${cfg_src}" ]; then
  fail_status "Konfigurasi rclone tidak ditemukan"
  exit 1
fi

cp "${cfg_src}" "${cfg}"
export RCLONE_CONFIG="${cfg}"

db_dir="${backup_root}/db"
files_dir="${backup_root}/files"
meta_dir="${backup_root}/meta"
mkdir -p "${db_dir}" "${files_dir}" "${meta_dir}"

lock_dir="${backup_root}/.manual_backup_lock"
if ! mkdir "${lock_dir}" 2>/dev/null; then
  printf "progress=0\nmessage=Backup sedang berjalan\ndone=0\nerror=\n" > "${status_file}"
  exit 0
fi
echo "${run_id}" > "${lock_dir}/run_id" || true
trap 'rm -f "${cfg}" 2>/dev/null || true; rm -f "${lock_dir}/run_id" 2>/dev/null || true; rmdir "${lock_dir}" 2>/dev/null || true' EXIT

ts="$(date -u +%Y%m%dT%H%M%SZ)"
log="${backup_root}/backup.log"

retention_db="${RETENTION_DAYS_DB:-14}"
retention_files="${RETENTION_DAYS_FILES:-14}"

echo "=== manual backup start ${ts} ===" >> "${log}"
update_status 5 "Memulai backup"

export PGPASSWORD="${DB_PASSWORD:-}"
update_status 20 "Backup database"
if ! pg_dump -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USERNAME:-app}" "${DB_DATABASE:-app}" \
  | gzip -c > "${db_dir}/db_${ts}.sql.gz"; then
  fail_status "Backup database gagal"
  exit 1
fi

update_status 55 "Backup storage"
set +e
tar -C /var/www/html -czf "${files_dir}/storage_${ts}.tar.gz" storage/app >> "${log}" 2>&1
rc=$?
set -e
if [ "${rc}" -gt 1 ]; then
  fail_status "Backup storage gagal. Cek backup.log untuk detail."
  exit 1
fi

branding_files=()
for f in public/favicon.png public/favicon.ico public/images/power-pro-logo-plain.png public/images/power-pro-logo.png; do
  if [ -f "/var/www/html/${f}" ]; then branding_files+=("${f}"); fi
done
if [ "${#branding_files[@]}" -gt 0 ]; then
  update_status 70 "Backup branding"
  set +e
  tar -C /var/www/html -czf "${files_dir}/public_branding_${ts}.tar.gz" "${branding_files[@]}" >> "${log}" 2>&1
  rc=$?
  set -e
  if [ "${rc}" -gt 1 ]; then
    fail_status "Backup branding gagal. Cek backup.log untuk detail."
    exit 1
  fi
fi

update_status 80 "Membersihkan backup lama"
find "${db_dir}" -type f -name 'db_*.sql.gz' -mtime +"${retention_db}" -delete 2>/dev/null || true
find "${files_dir}" -type f -name 'storage_*.tar.gz' -mtime +"${retention_files}" -delete 2>/dev/null || true
find "${files_dir}" -type f -name 'public_branding_*.tar.gz' -mtime +"${retention_files}" -delete 2>/dev/null || true
find "${meta_dir}" -type f -name 'sha256_*' -mtime +"${retention_files}" -delete 2>/dev/null || true

dest="${remote}:${path}"
echo "Sync ke ${dest} ..." >> "${log}"
sha_db="${meta_dir}/sha256_db_${ts}.txt"
sha_files="${meta_dir}/sha256_files_${ts}.txt"
sha_branding=""

echo "$(sha256sum "${db_dir}/db_${ts}.sql.gz" | awk '{print $1}')" > "${sha_db}"
echo "$(sha256sum "${files_dir}/storage_${ts}.tar.gz" | awk '{print $1}')" > "${sha_files}"

if [ -f "${files_dir}/public_branding_${ts}.tar.gz" ]; then
  sha_branding="${meta_dir}/sha256_branding_${ts}.txt"
  echo "$(sha256sum "${files_dir}/public_branding_${ts}.tar.gz" | awk '{print $1}')" > "${sha_branding}"
fi

update_status 85 "Membuat bundle"
bundle="${meta_dir}/powerpro_manual_bundle_${ts}.tar.gz"
bundle_items=(
  "db/db_${ts}.sql.gz"
  "files/storage_${ts}.tar.gz"
  "meta/sha256_db_${ts}.txt"
  "meta/sha256_files_${ts}.txt"
)
if [ -f "${files_dir}/public_branding_${ts}.tar.gz" ]; then
  bundle_items+=("files/public_branding_${ts}.tar.gz")
fi
if [ -n "${sha_branding}" ]; then
  bundle_items+=("meta/sha256_branding_${ts}.txt")
fi
tar -C "${backup_root}" -czf "${bundle}" "${bundle_items[@]}" >> "${log}" 2>&1

update_status 92 "Upload ke Google Drive"
remote_bundle="${dest}/bundles/powerpro_manual_bundle_${ts}.tar.gz"
echo "Upload bundle ke ${remote_bundle} ..." >> "${log}"
if ! rclone copyto "${bundle}" "${remote_bundle}" \
  --drive-chunk-size 64M \
  --transfers 4 \
  --checkers 8 \
  --retries 3 \
  --stats-one-line --stats 30s \
  >> "${log}" 2>&1; then
  fail_status "Upload ke Google Drive gagal (rclone)"
  exit 1
fi

update_status 96 "Finalisasi"
find "${meta_dir}" -type f -name 'powerpro_manual_bundle_*.tar.gz' -mtime +"${retention_files}" -delete 2>/dev/null || true

echo "=== manual backup done ${ts} ===" >> "${log}"
printf "progress=100\nmessage=Backup selesai\ndone=1\nerror=\n" > "${status_file}"
BASH;

        $baseEnv = [];
        foreach (array_merge((array) $_ENV, (array) $_SERVER) as $k => $v) {
            if (!is_string($k)) continue;
            if (!is_scalar($v)) continue;
            $baseEnv[$k] = (string) $v;
        }
        if (!isset($baseEnv['PATH'])) {
            $baseEnv['PATH'] = (string) (getenv('PATH') ?: '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin');
        }

        $process = new Process(['/bin/bash', '-lc', $script], base_path(), array_merge($baseEnv, [
            'BACKUP_DIR' => $root,
            'RCLONE_REMOTE' => $remote,
            'RCLONE_PATH' => $path,
            'RUN_ID' => $runId,
            'STATUS_FILE' => $statusFile,
            'DB_HOST' => env('DB_HOST', 'db'),
            'DB_PORT' => (string) env('DB_PORT', '5432'),
            'DB_DATABASE' => env('DB_DATABASE', 'app'),
            'DB_USERNAME' => env('DB_USERNAME', 'app'),
            'DB_PASSWORD' => env('DB_PASSWORD', ''),
            'RETENTION_DAYS_DB' => (string) env('RETENTION_DAYS_DB', '14'),
            'RETENTION_DAYS_FILES' => (string) env('RETENTION_DAYS_FILES', '14'),
        ]));
        $process->setTimeout(null);
        $process->disableOutput();
        $process->setOptions(['create_new_console' => true]);
        try {
            $process->start();
        } catch (\Throwable) {
            @file_put_contents($statusFile, "progress=100\nmessage=Backup gagal\ndone=1\nerror=Gagal menjalankan proses backup\n");
            return response()->json([
                'runId' => $runId,
                'alreadyRunning' => false,
                'error' => 'Gagal menjalankan proses backup. Server tidak bisa menjalankan runner.',
            ], 500);
        }

        $payload = [
            'runId' => $runId,
            'alreadyRunning' => false,
        ];
        return response()->json($payload);
    }

    public function status(string $runId)
    {
        $root = env('BACKUP_DIR') ?: storage_path('backup/manual');
        $statusFile = rtrim($root, '/')."/meta/manual_status_{$runId}.txt";
        if (!is_file($statusFile)) {
            $lockDir = rtrim($root, '/').'/.manual_backup_lock';
            $lockRunId = is_dir($lockDir) ? @trim((string) @file_get_contents($lockDir.'/run_id')) : '';
            if ($lockRunId === $runId) {
                return response()->json([
                    'runId' => $runId,
                    'progress' => 5,
                    'done' => false,
                    'message' => 'Backup sedang dimulai...',
                    'error' => '',
                ]);
            }
            return response()->json([
                'runId' => $runId,
                'progress' => 100,
                'done' => true,
                'message' => 'Backup gagal',
                'error' => 'Status backup tidak ditemukan (permission atau runner gagal). Silakan klik Backup lagi.',
            ]);
        }

        $content = File::get($statusFile);
        $parsed = $this->parseStatusFile($content);

        $lockDir = rtrim($root, '/').'/.manual_backup_lock';
        $age = is_file($statusFile) ? (time() - (int) @filemtime($statusFile)) : null;
        $lockRunId = is_dir($lockDir) ? @trim((string) @file_get_contents($lockDir.'/run_id')) : '';

        if (
            (int) ($parsed['progress'] ?? 0) <= 1
            && !(bool) ($parsed['done'] ?? false)
            && is_file($statusFile)
            && $age !== null
            && $age > 60
            && $lockRunId === ''
        ) {
            $parsed = [
                'progress' => 100,
                'done' => true,
                'message' => 'Backup gagal',
                'error' => 'Backup tidak berjalan (runner gagal atau lock stale). Silakan klik Backup lagi.',
            ];
        }

        if (
            (int) ($parsed['progress'] ?? 0) >= 80
            && !(bool) ($parsed['done'] ?? false)
            && $age !== null
            && $age > 15 * 60
            && $lockRunId === $runId
        ) {
            @unlink($lockDir.'/run_id');
            @rmdir($lockDir);
            $parsed = [
                'progress' => 100,
                'done' => true,
                'message' => 'Backup gagal',
                'error' => 'Proses backup berhenti sebelum selesai. Silakan klik Backup lagi.',
            ];
        }

        return response()->json([
            'runId' => $runId,
            ...$parsed,
        ]);
    }
}
