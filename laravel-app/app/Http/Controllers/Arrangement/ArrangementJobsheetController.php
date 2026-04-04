<?php

namespace App\Http\Controllers\Arrangement;

use App\Http\Controllers\Controller;
use App\Models\ArrangementJobsheetPeriod;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response;

class ArrangementJobsheetController extends Controller
{
    public function index(Request $request): Response
    {
        $user = $request->user();
        $isManager = (bool) $user?->hasAnyRole(['Administrator', 'Admin Officer']);

        $periods = ArrangementJobsheetPeriod::query()
            ->with('creator:id,name')
            ->orderByDesc('start_date')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (ArrangementJobsheetPeriod $p) => [
                'id' => $p->id,
                'name' => $p->name,
                'start_date' => $p->start_date?->toDateString(),
                'end_date' => $p->end_date?->toDateString(),
                'created_by' => $p->created_by,
                'created_by_name' => $p->creator?->name,
            ])
            ->values()
            ->all();

        $selectedId = (string) $request->query('period', '');
        $selectedPeriod = null;
        if ($selectedId && Str::isUuid($selectedId)) {
            $selectedPeriod = ArrangementJobsheetPeriod::query()->find($selectedId);
        }
        if (! $selectedPeriod) {
            $selectedPeriod = ArrangementJobsheetPeriod::query()
                ->orderByDesc('start_date')
                ->orderByDesc('created_at')
                ->first();
        }

        $selectedPeriodPayload = $selectedPeriod
            ? [
                'id' => $selectedPeriod->id,
                'name' => $selectedPeriod->name,
                'start_date' => $selectedPeriod->start_date?->toDateString(),
                'end_date' => $selectedPeriod->end_date?->toDateString(),
                'created_by' => $selectedPeriod->created_by,
            ]
            : null;

        $pics = User::query()
            ->where('status', 'Active')
            ->where('is_internal', true)
            ->orderBy('id')
            ->get(['id', 'name'])
            ->map(fn (User $u) => ['id' => $u->id, 'name' => $u->name])
            ->values()
            ->all();

        return Inertia::render('Arrangement/Jobsheet', [
            'isManager' => $isManager,
            'pics' => $pics,
            'holidays' => config('jobsheet.holidays', []),
            'periods' => $periods,
            'selectedPeriod' => $selectedPeriodPayload,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
        ]);

        $period = ArrangementJobsheetPeriod::query()->create([
            'name' => $data['name'],
            'start_date' => $data['start_date'],
            'end_date' => $data['end_date'],
            'created_by' => (int) $request->user()->id,
        ]);

        return redirect()->route('arrangements.jobsheet', ['period' => $period->id]);
    }
}
