<?php

namespace App\Http\Controllers\Arrangement;

use App\Http\Controllers\Controller;
use App\Models\ArrangementBatch;
use App\Models\ArrangementSchedule;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class ArrangementSchedulesController extends Controller
{
    public function index(): Response
    {
        $schedules = ArrangementSchedule::query()
            ->withCount('pickups')
            ->with('batch:id,name,requirement_points')
            ->orderByDesc('created_at')
            ->paginate(50)
            ->withQueryString();

        $batches = ArrangementBatch::query()
            ->orderByDesc('created_at')
            ->get(['id', 'name', 'requirement_points']);

        return Inertia::render('Arrangement/Schedules', [
            'schedules' => $schedules,
            'batches' => $batches,
            'scheduleTypes' => ['Middle', 'Duty', 'Saturday', 'Sunday', 'Public Holiday'],
            'statusOptions' => ['Open', 'Batched', 'Picked Up', 'Approved'],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $duplicateCount = (int) $data['count'];
        $duplicateCount = max(1, min(20, $duplicateCount));

        DB::transaction(function () use ($data, $request, $duplicateCount) {
            for ($i = 0; $i < $duplicateCount; $i++) {
                ArrangementSchedule::query()->create([
                    'batch_id' => null,
                    'schedule_type' => $data['schedule_type'],
                    'note' => $data['note'] ?? null,
                    'start_date' => $data['start_date'],
                    'end_date' => $data['end_date'],
                    'count' => 1,
                    'status' => 'Open',
                    'created_by' => $request->user()->id,
                ]);
            }
        });

        return back();
    }

    public function update(Request $request, ArrangementSchedule $schedule): RedirectResponse
    {
        if (! in_array($schedule->status, ['Open', 'Publish']) && ! $request->user()->hasAnyRole(['Administrator', 'Admin Officer'])) {
            abort(403, 'Hanya status Open yang dapat diubah.');
        }

        $data = $this->validated($request, $schedule);

        $schedule->forceFill([
            'schedule_type' => $data['schedule_type'],
            'note' => $data['note'] ?? null,
            'start_date' => $data['start_date'],
            'end_date' => $data['end_date'],
        ]);

        $schedule->save();

        return back();
    }

    public function destroy(Request $request, ArrangementSchedule $schedule): RedirectResponse
    {
        if (! in_array($schedule->status, ['Open', 'Publish']) && ! $request->user()->hasAnyRole(['Administrator', 'Admin Officer'])) {
            abort(403, 'Hanya status Open yang dapat dihapus.');
        }

        $schedule->delete();

        return back();
    }

    public function approve(Request $request, ArrangementSchedule $schedule): RedirectResponse
    {
        if ($schedule->status !== 'Picked Up') {
            abort(422);
        }

        $schedule->forceFill([
            'status' => 'Approved',
            'approved_by' => $request->user()->id,
            'approved_at' => now(),
        ])->save();

        return back();
    }

    public function reopen(Request $request, ArrangementSchedule $schedule): RedirectResponse
    {
        if ($schedule->status === 'Approved' && ! $request->user()->hasAnyRole(['Administrator', 'Admin Officer'])) {
            abort(403);
        }

        $schedule->forceFill([
            'status' => 'Open',
            'approved_by' => null,
            'approved_at' => null,
        ])->save();

        return back();
    }

    private function validated(Request $request, ?ArrangementSchedule $schedule = null): array
    {
        return $request->validate([
            'batch_id' => ['nullable', 'uuid', Rule::exists('arrangement_batches', 'id')],
            'schedule_type' => ['required', 'string', Rule::in(['Middle', 'Duty', 'Saturday', 'Sunday', 'Public Holiday'])],
            'note' => ['nullable', 'string'],
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
            'count' => ['required', 'integer', 'min:1', 'max:20'],
            'status' => ['nullable', 'string', Rule::in(['Open', 'Batched', 'Picked Up', 'Approved', 'Publish'])],
        ]);
    }
}
