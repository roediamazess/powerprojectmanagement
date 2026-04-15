<?php
require 'laravel-app/vendor/autoload.php';
$app = require_once 'laravel-app/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$statuses = \App\Models\ArrangementSchedule::select('status', \Illuminate\Support\Facades\DB::raw('count(*) as count'))
    ->groupBy('status')
    ->get()
    ->toArray();

print_r($statuses);
