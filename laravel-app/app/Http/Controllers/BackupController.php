<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Inertia\Inertia;
use Spatie\Backup\BackupDestination\Backup;
use Spatie\Backup\BackupDestination\BackupDestination;
use Illuminate\Support\Facades\Storage;

class BackupController extends Controller
{
    public function index()
    {
        $backups = [];
        $diskStatuses = [];
        
        // Get backups from local and google disks
        foreach (['local', 'google'] as $diskName) {
            try {
                $diskStatuses[$diskName] = [
                    'ok' => true,
                    'error' => null,
                ];
                $files = Storage::disk($diskName)->allFiles(config('backup.backup.name'));
                foreach ($files as $file) {
                    if (str_ends_with($file, '.zip')) {
                        $backups[] = [
                            'name' => basename($file),
                            'size' => round(Storage::disk($diskName)->size($file) / 1024 / 1024, 2) . ' MB',
                            'date' => date('Y-m-d H:i:s', Storage::disk($diskName)->lastModified($file)),
                            'disk' => $diskName,
                            'path' => $file
                        ];
                    }
                }
            } catch (\Throwable $e) {
                $diskStatuses[$diskName] = [
                    'ok' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        // Sort by date desc
        usort($backups, fn($a, $b) => strcmp($b['date'], $a['date']));

        return Inertia::render('Backups/Index', [
            'backups' => $backups,
            'diskStatuses' => $diskStatuses,
        ]);
    }

    public function create()
    {
        // Run backup in background to avoid timeout
        Artisan::call('backup:run --only-db');
        
        return redirect()->back()->with('success', 'Backup database started successfully.');
    }

    public function createFull()
    {
        // Run full backup (files + db)
        Artisan::call('backup:run');
        
        return redirect()->back()->with('success', 'Full backup started successfully.');
    }

    public function download($disk, $path)
    {
        if (!in_array($disk, ['local', 'google'])) {
            abort(403);
        }
        
        return Storage::disk($disk)->download(base64_decode($path));
    }
}
