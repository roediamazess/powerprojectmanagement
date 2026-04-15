<?php
$base = '/home/ubuntu/power-project-management/laravel-app';
require $base . '/vendor/autoload.php';
$app = require_once $base . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\ArrangementSchedule;
use Illuminate\Support\Facades\DB;

$statuses = ArrangementSchedule::select('status', DB::raw('count(*) as count'))
    ->groupBy('status')
    ->get()
    ->toArray();

print_r($statuses);
