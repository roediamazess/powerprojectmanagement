<?php

namespace App\Http\Controllers\Arrangement;

use App\Http\Controllers\Controller;
use App\Models\ArrangementBatch;
use App\Models\ArrangementSchedule;
use Carbon\CarbonImmutable;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

class ArrangementBatchesController extends Controller
{
    public function index(): Response
    {
        $tz = 'Asia/Jakarta';

        $lastWindowBatch = ArrangementBatch::query()
            ->whereNotNull('pickup_start_at')
            ->whereNotNull('pickup_end_at')
            ->orderByDesc('created_at')
            ->first(['pickup_start_at', 'pickup_end_at', 'min_requirement_points', 'max_requirement_points', 'requirement_points']);

        $defaultPickupWindow = null;
        if ($lastWindowBatch?->pickup_start_at && $lastWindowBatch?->pickup_end_at) {
            $defaultPickupWindow = [
                'start' => CarbonImmutable::parse($lastWindowBatch->pickup_start_at)->setTimezone($tz)->format('Y-m-d\TH:i'),
                'end' => CarbonImmutable::parse($lastWindowBatch->pickup_end_at)->setTimezone($tz)->format('Y-m-d\TH:i'),
                'tz' => $tz,
            ];
        } else {
            $start = CarbonImmutable::now($tz)->startOfDay();
            $end = CarbonImmutable::now($tz)->endOfDay()->setTime(23, 59);
            $defaultPickupWindow = [
                'start' => $start->format('Y-m-d\TH:i'),
                'end' => $end->format('Y-m-d\TH:i'),
                'tz' => $tz,
            ];
        }

        $min = (int) ($lastWindowBatch?->min_requirement_points ?? 0);
        $max = (int) (($lastWindowBatch?->max_requirement_points ?: ($lastWindowBatch?->requirement_points ?: 0)));
        if ($max <= 0) $max = 100;
        $defaultRequirementPoints = [
            'min' => $min,
            'max' => $max,
        ];

        $batches = ArrangementBatch::query()
            ->withCount('schedules')
            ->orderByDesc('created_at')
            ->paginate(50)
            ->withQueryString();

        $publishSchedules = ArrangementSchedule::query()
            ->whereIn('status', ['Open', 'Batched', 'Publish']) // Also include publish
            ->orderBy('start_date')
            ->get();

        // Debug log
        \Illuminate\Support\Facades\Log::info('Batches index debug', [
            'total_found' => $publishSchedules->count(),
            'statuses' => $publishSchedules->pluck('status')->unique()->values()->all()
        ]);

        return Inertia::render('Arrangement/Batches', [
            'batches' => $batches,
            'publishSchedules' => $publishSchedules,
            'defaultPickupWindow' => $defaultPickupWindow,
            'defaultRequirementPoints' => $defaultRequirementPoints,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'min_requirement_points' => ['required', 'integer', 'min:0', 'max:999'],
            'max_requirement_points' => ['required', 'integer', 'min:0', 'max:999', 'gte:min_requirement_points'],
            'pickup_start_at' => ['required', 'date_format:Y-m-d\\TH:i'],
            'pickup_end_at' => ['required', 'date_format:Y-m-d\\TH:i', 'after_or_equal:pickup_start_at'],
            'schedule_ids' => ['nullable', 'array'],
            'schedule_ids.*' => ['uuid', Rule::exists('arrangement_schedules', 'id')],
        ]);

        $tz = 'Asia/Jakarta';
        $startUtc = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', $data['pickup_start_at'], $tz)->utc();
        $endUtc = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', $data['pickup_end_at'], $tz)->utc();

        $batch = ArrangementBatch::query()->create([
            'name' => $data['name'],
            'requirement_points' => $data['max_requirement_points'],
            'min_requirement_points' => $data['min_requirement_points'],
            'max_requirement_points' => $data['max_requirement_points'],
            'status' => 'Open',
            'pickup_start_at' => $startUtc,
            'pickup_end_at' => $endUtc,
            'created_by' => $request->user()->id,
        ]);

        if (! empty($data['schedule_ids'])) {
            ArrangementSchedule::query()
                ->whereIn('id', $data['schedule_ids'])
                ->where('status', 'Open')
                ->update([
                    'batch_id' => $batch->id,
                    'status' => 'Batched'
                ]);
        }

        return back();
    }

    public function update(Request $request, ArrangementBatch $batch): RedirectResponse
    {
        if ($batch->status === 'Approved') {
            throw ValidationException::withMessages([
                'batch' => 'Batch sudah Approved. Silakan Reopen dulu untuk mengubah batch.',
            ]);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'min_requirement_points' => ['required', 'integer', 'min:0', 'max:999'],
            'max_requirement_points' => ['required', 'integer', 'min:0', 'max:999', 'gte:min_requirement_points'],
            'pickup_start_at' => ['required', 'date_format:Y-m-d\\TH:i'],
            'pickup_end_at' => ['required', 'date_format:Y-m-d\\TH:i', 'after_or_equal:pickup_start_at'],
            'schedule_ids' => ['nullable', 'array'],
            'schedule_ids.*' => ['uuid', Rule::exists('arrangement_schedules', 'id')],
        ]);

        $tz = 'Asia/Jakarta';
        $startUtc = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', $data['pickup_start_at'], $tz)->utc();
        $endUtc = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', $data['pickup_end_at'], $tz)->utc();

        $batch->forceFill([
            'name' => $data['name'],
            'requirement_points' => $data['max_requirement_points'],
            'min_requirement_points' => $data['min_requirement_points'],
            'max_requirement_points' => $data['max_requirement_points'],
            'pickup_start_at' => $startUtc,
            'pickup_end_at' => $endUtc,
        ])->save();

        if (array_key_exists('schedule_ids', $data)) {
            $hasProtected = ArrangementSchedule::query()
                ->where('batch_id', $batch->id)
                ->whereNotIn('status', ['Open', 'Batched', 'Publish'])
                ->exists();

            if ($hasProtected && ! $request->user()->hasAnyRole(['Administrator', 'Admin Officer'])) {
                return back()->withErrors(['schedule_ids' => 'Proses batching tidak dapat diubah karena ada schedule yang sudah Picked Up atau Approved.']);
            }

            // Reset current batch's schedules that are NOT protected
            ArrangementSchedule::query()
                ->where('batch_id', $batch->id)
                ->whereIn('status', ['Open', 'Batched', 'Publish'])
                ->update([
                    'batch_id' => null,
                    'status' => 'Open'
                ]);

            if (! empty($data['schedule_ids'])) {
                ArrangementSchedule::query()
                    ->whereIn('id', $data['schedule_ids'])
                    ->whereIn('status', ['Open', 'Publish'])
                    ->update([
                        'batch_id' => $batch->id,
                        'status' => 'Batched'
                    ]);
            }
        }

        return back();
    }

    public function approve(Request $request, ArrangementBatch $batch): RedirectResponse
    {
        $batch->forceFill([
            'status' => 'Approved',
        ])->save();

        return back();
    }

    public function reopen(Request $request, ArrangementBatch $batch): RedirectResponse
    {
        $batch->forceFill([
            'status' => 'Open',
        ])->save();

        return back();
    }
}
