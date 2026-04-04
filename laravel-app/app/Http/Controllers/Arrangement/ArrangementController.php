<?php

namespace App\Http\Controllers\Arrangement;

use App\Http\Controllers\Controller;
use App\Models\ArrangementBatch;
use App\Models\ArrangementSchedule;
use App\Models\ArrangementSchedulePickup;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ArrangementController extends Controller
{
    public function index(Request $request): Response
    {
        $user = $request->user();
        $isManager = $user->hasAnyRole(['Administrator', 'Admin Officer']);

        $availableSchedules = ArrangementSchedule::query()
            ->with([
                'batch:id,name,requirement_points',
                'pickups:id,schedule_id,user_id,points',
                'pickups.user:id,name,tier',
            ])
            ->whereIn('status', ['Batched', 'Picked Up', 'Approved'])
            ->whereHas('batch', function ($q) {
                $q->where('status', 'Approved');
            })
            ->orderBy('start_date')
            ->orderBy('end_date')
            ->get();

        $batches = ArrangementBatch::query()
            ->where('status', 'Approved')
            ->with([
                'schedules' => function ($q) {
                    $q->select('id', 'batch_id', 'schedule_type', 'note', 'start_date', 'end_date', 'count', 'status')
                        ->whereIn('status', ['Batched', 'Picked Up', 'Approved'])
                        ->orderBy('start_date')
                        ->orderBy('end_date');
                },
                'schedules.pickups:id,schedule_id,user_id,points',
                'schedules.pickups.user:id,name,tier',
            ])
            ->orderBy('created_at', 'desc')
            ->get(['id', 'name', 'status', 'requirement_points', 'min_requirement_points', 'max_requirement_points', 'pickup_start_at', 'pickup_end_at']);

        $myPickups = ArrangementSchedulePickup::query()
            ->with([
                'schedule:id,batch_id,schedule_type,start_date,end_date,count,status',
                'schedule.batch:id,name,requirement_points',
            ])
            ->where('user_id', $user->id)
            ->latest()
            ->get();

        return Inertia::render('Arrangement/Index', [
            'isManager' => $isManager,
            'availableSchedules' => $availableSchedules,
            'batches' => $batches,
            'myPickups' => $myPickups,
            'myPoints' => self::tierPoints($user->tier),
        ]);
    }


    public static function tierPoints(?string $tier): int
    {
        $t = strtolower(trim((string) $tier));

        return match ($t) {
            'tier 4' => 4,
            'tier 3' => 3,
            'tier 2' => 2,
            'tier 1', 'new born' => 1,
            default => 1,
        };
    }
}
