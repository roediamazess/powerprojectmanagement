<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\File;
use Inertia\Inertia;

class BackupsController extends Controller
{
    public function index()
    {
        $base = base_path('.backups/powerpro');
        $root = env('BACKUP_DIR', $base);
        $dbDir = $root.'/db';
        $filesDir = $root.'/files';
        $metaDir = $root.'/meta';

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

        $cronDaily = '10 2 * * * cd '.base_path().' && DO_UPLOAD=1 RCLONE_REMOTE=gdrive RCLONE_PATH=powerpro /usr/bin/env bash '.base_path('laravel-app/backup.sh').' all >> '.$root.'/backup.log 2>&1';
        $cronWeekly = '10 3 * * 0 cd '.base_path().' && DO_UPLOAD=1 RCLONE_REMOTE=gdrive RCLONE_PATH=powerpro RETENTION_DAYS_DB=60 RETENTION_DAYS_FILES=60 /usr/bin/env bash '.base_path('laravel-app/backup.sh').' all >> '.$root.'/backup.log 2>&1';

        return Inertia::render('Backups/Index', [
            'root' => $root,
            'items' => $latest,
            'cron' => [
                'daily' => $cronDaily,
                'weekly' => $cronWeekly,
            ],
        ]);
    }
}
