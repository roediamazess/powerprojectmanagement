<?php

namespace App\Http\Controllers\Tables;

use App\Http\Controllers\Controller;
use App\Models\PartnerSetupOption;
use App\Models\Partner;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class PartnerSetupController extends Controller
{
    private const CATEGORIES = [
        'implementation_type',
        'system_version',
        'type',
        'group',
        'area',
        'sub_area',
    ];

    public function index(Request $request): Response
    {
        $category = $request->query('category', 'implementation_type');
        if (! in_array($category, self::CATEGORIES, true)) {
            $category = 'implementation_type';
        }

        $usedValues = $this->usedValuesForCategory($category);

        $options = PartnerSetupOption::query()
            ->where('category', $category)
            ->orderBy('name')
            ->get()
            ->map(fn (PartnerSetupOption $o) => [
                'id' => $o->id,
                'category' => $o->category,
                'name' => $o->name,
                'status' => $o->status,
                'in_use' => in_array($o->name, $usedValues, true),
            ])
            ->values();

        return Inertia::render('Tables/PartnerSetup/Index', [
            'category' => $category,
            'categories' => collect(self::CATEGORIES)->map(fn (string $c) => [
                'key' => $c,
                'label' => $this->categoryLabel($c),
            ])->values(),
            'options' => $options,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'category' => ['required', 'string', Rule::in(self::CATEGORIES)],
            'name' => ['required', 'string', 'max:255', Rule::unique('partner_setup_options', 'name')->where(fn ($q) => $q->where('category', $request->input('category')))],
            'status' => ['required', 'string', Rule::in(['Active', 'Inactive'])],
        ]);

        PartnerSetupOption::query()->create([
            'category' => $data['category'],
            'name' => $data['name'],
            'status' => $data['status'],
        ]);

        return redirect()->route('tables.partner-setup.index', ['category' => $data['category']]);
    }

    public function update(Request $request, PartnerSetupOption $option): RedirectResponse
    {
        $category = $request->input('category');

        $data = $request->validate([
            'category' => ['required', 'string', Rule::in(self::CATEGORIES)],
            'name' => ['required', 'string', 'max:255', Rule::unique('partner_setup_options', 'name')->where(fn ($q) => $q->where('category', $category))->ignore($option->id)],
            'status' => ['required', 'string', Rule::in(['Active', 'Inactive'])],
        ]);

        $inUse = $this->optionInUse($option->category, $option->name);
        if ($inUse && ($data['category'] !== $option->category || $data['name'] !== $option->name)) {
            return back()->withErrors(['name' => 'Tidak bisa mengubah Category/Name karena option sudah dipakai di data Partners.']);
        }

        $option->update([
            'category' => $data['category'],
            'name' => $data['name'],
            'status' => $data['status'],
        ]);

        return redirect()->route('tables.partner-setup.index', ['category' => $data['category']]);
    }

    public function destroy(Request $request, PartnerSetupOption $option): RedirectResponse
    {
        $category = $option->category;

        if ($this->optionInUse($option->category, $option->name)) {
            return redirect()->route('tables.partner-setup.index', ['category' => $category])
                ->withErrors(['delete' => 'Tidak bisa menghapus option karena sudah dipakai di data Partners. Set status ke Inactive saja.']);
        }

        $option->delete();

        return redirect()->route('tables.partner-setup.index', ['category' => $category]);
    }

    

    private function usedValuesForCategory(string $category): array
    {
        if (! in_array($category, self::CATEGORIES, true)) return [];

        return Partner::query()
            ->select($category)
            ->whereNotNull($category)
            ->distinct()
            ->orderBy($category)
            ->pluck($category)
            ->filter()
            ->values()
            ->all();
    }

    private function optionInUse(string $category, string $name): bool
    {
        if (! in_array($category, self::CATEGORIES, true)) return false;
        if ($name === '') return false;

        return Partner::query()->where($category, $name)->exists();
    }

private function categoryLabel(string $key): string
    {
        return match ($key) {
            'implementation_type' => 'Implementation Type',
            'system_version' => 'System Version',
            'type' => 'Type',
            'group' => 'Group',
            'area' => 'Area',
            'sub_area' => 'Sub Area',
            default => $key,
        };
    }
}
