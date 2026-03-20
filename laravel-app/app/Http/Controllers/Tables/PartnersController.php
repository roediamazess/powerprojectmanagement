<?php

namespace App\Http\Controllers\Tables;

use App\Http\Controllers\Controller;
use App\Models\Partner;
use App\Models\PartnerSetupOption;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class PartnersController extends Controller
{
    private const STAR_OPTIONS = [5, 4, 3, 2, 1];

    private const STATUS_OPTIONS = [
        'Active',
        'Inactive',
        'Freeze',
    ];

    private const SETUP_CATEGORIES = [
        'implementation_type',
        'system_version',
        'type',
        'group',
        'area',
        'sub_area',
    ];

    public function index(): Response
    {
        $partners = Partner::query()
            ->orderBy('id')
            ->get()
            ->map(fn (Partner $p) => [
                'id' => $p->id,
                'cnc_id' => $p->cnc_id,
                'name' => $p->name,
                'star' => $p->star,
                'room' => $p->room,
                'outlet' => $p->outlet,
                'status' => $p->status,
                'system_live' => $p->system_live?->toDateString(),
                'implementation_type' => $p->implementation_type,
                'system_version' => $p->system_version,
                'type' => $p->type,
                'group' => $p->group,
                'address' => $p->address,
                'area' => $p->area,
                'sub_area' => $p->sub_area,
                'gm_email' => $p->gm_email,
                'fc_email' => $p->fc_email,
                'ca_email' => $p->ca_email,
                'cc_email' => $p->cc_email,
                'ia_email' => $p->ia_email,
                'it_email' => $p->it_email,
                'hrd_email' => $p->hrd_email,
                'fom_email' => $p->fom_email,
                'dos_email' => $p->dos_email,
                'ehk_email' => $p->ehk_email,
                'fbm_email' => $p->fbm_email,
                'last_visit' => $p->last_visit?->toDateString(),
                'last_visit_type' => $p->last_visit_type,
                'last_project' => $p->last_project,
                'last_project_type' => $p->last_project_type,
            ])
            ->values();

        $setupOptions = PartnerSetupOption::query()
            ->whereIn('category', self::SETUP_CATEGORIES)
            ->orderBy('category')
            ->orderBy('name')
            ->get()
            ->groupBy('category')
            ->map(fn ($items) => $items->map(fn ($o) => ['name' => $o->name, 'status' => $o->status])->values())
            ->toArray();

        return Inertia::render('Tables/Partners/Index', [
            'partners' => $partners,
            'starOptions' => self::STAR_OPTIONS,
            'statusOptions' => self::STATUS_OPTIONS,
            'setupOptions' => $setupOptions,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validatePartner($request);

        Partner::query()->create($data);

        return redirect()->route('tables.partners.index');
    }

    public function update(Request $request, Partner $partner): RedirectResponse
    {
        $data = $this->validatePartner($request, $partner);
        $partner->update($data);

        return redirect()->route('tables.partners.index');
    }

    public function destroy(Request $request, Partner $partner): RedirectResponse
    {
        $partner->delete();

        return redirect()->route('tables.partners.index');
    }

    private function validatePartner(Request $request, ?Partner $partner = null): array
    {
        $id = $partner?->id;

        return $request->validate([
            'cnc_id' => ['required', 'string', 'max:50', Rule::unique('partners', 'cnc_id')->ignore($id)],
            'name' => ['required', 'string', 'max:255'],
            'star' => ['nullable', 'integer', Rule::in(self::STAR_OPTIONS)],
            'room' => ['nullable', 'string', 'max:50'],
            'outlet' => ['nullable', 'string', 'max:50'],
            'status' => ['required', 'string', Rule::in(self::STATUS_OPTIONS)],
            'system_live' => ['nullable', 'date'],
            'implementation_type' => ['nullable', 'string', 'max:255'],
            'system_version' => ['nullable', 'string', 'max:255'],
            'type' => ['nullable', 'string', 'max:255'],
            'group' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string'],
            'area' => ['nullable', 'string', 'max:255'],
            'sub_area' => ['nullable', 'string', 'max:255'],
            'gm_email' => ['nullable', 'string', 'email', 'max:255'],
            'fc_email' => ['nullable', 'string', 'email', 'max:255'],
            'ca_email' => ['nullable', 'string', 'email', 'max:255'],
            'cc_email' => ['nullable', 'string', 'email', 'max:255'],
            'ia_email' => ['nullable', 'string', 'email', 'max:255'],
            'it_email' => ['nullable', 'string', 'email', 'max:255'],
            'hrd_email' => ['nullable', 'string', 'email', 'max:255'],
            'fom_email' => ['nullable', 'string', 'email', 'max:255'],
            'dos_email' => ['nullable', 'string', 'email', 'max:255'],
            'ehk_email' => ['nullable', 'string', 'email', 'max:255'],
            'fbm_email' => ['nullable', 'string', 'email', 'max:255'],
            'last_visit' => ['nullable', 'date'],
            'last_visit_type' => ['nullable', 'string', 'max:255'],
            'last_project' => ['nullable', 'string', 'max:255'],
            'last_project_type' => ['nullable', 'string', 'max:255'],
        ]);
    }
}
