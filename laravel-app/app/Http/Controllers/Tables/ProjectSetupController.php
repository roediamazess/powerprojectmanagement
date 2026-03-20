<?php

namespace App\Http\Controllers\Tables;

use App\Http\Controllers\Controller;
use App\Models\Project;
use App\Models\ProjectSetupOption;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class ProjectSetupController extends Controller
{
    private const CATEGORIES = [
        'type',
        'status',
    ];

    public function index(Request $request): Response
    {
        $category = $request->query('category', 'type');
        if (! in_array($category, self::CATEGORIES, true)) {
            $category = 'type';
        }

        $usedValues = $this->usedValuesForCategory($category);

        $options = ProjectSetupOption::query()
            ->where('category', $category)
            ->orderBy('name')
            ->get()
            ->map(fn (ProjectSetupOption $o) => [
                'id' => $o->id,
                'category' => $o->category,
                'name' => $o->name,
                'status' => $o->status,
                'in_use' => in_array($o->name, $usedValues, true),
            ])
            ->values();

        return Inertia::render('Tables/ProjectSetup/Index', [
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
            'name' => ['required', 'string', 'max:255', Rule::unique('project_setup_options', 'name')->where(fn ($q) => $q->where('category', $request->input('category')))],
            'status' => ['required', 'string', Rule::in(['Active', 'Inactive'])],
        ]);

        ProjectSetupOption::query()->create([
            'category' => $data['category'],
            'name' => $data['name'],
            'status' => $data['status'],
        ]);

        return redirect()->route('tables.project-setup.index', ['category' => $data['category']]);
    }

    public function update(Request $request, ProjectSetupOption $option): RedirectResponse
    {
        $category = $request->input('category');

        $data = $request->validate([
            'category' => ['required', 'string', Rule::in(self::CATEGORIES)],
            'name' => ['required', 'string', 'max:255', Rule::unique('project_setup_options', 'name')->where(fn ($q) => $q->where('category', $category))->ignore($option->id)],
            'status' => ['required', 'string', Rule::in(['Active', 'Inactive'])],
        ]);

        $inUse = $this->optionInUse($option->category, $option->name);
        if ($inUse && ($data['category'] !== $option->category || $data['name'] !== $option->name)) {
            return back()->withErrors(['name' => 'Tidak bisa mengubah Category/Name karena option sudah dipakai di data Projects.']);
        }

        $option->update([
            'category' => $data['category'],
            'name' => $data['name'],
            'status' => $data['status'],
        ]);

        return redirect()->route('tables.project-setup.index', ['category' => $data['category']]);
    }

    public function destroy(Request $request, ProjectSetupOption $option): RedirectResponse
    {
        $category = $option->category;

        if ($this->optionInUse($option->category, $option->name)) {
            return redirect()->route('tables.project-setup.index', ['category' => $category])
                ->withErrors(['delete' => 'Tidak bisa menghapus option karena sudah dipakai di data Projects. Set status ke Inactive saja.']);
        }

        $option->delete();

        return redirect()->route('tables.project-setup.index', ['category' => $category]);
    }

    private function usedValuesForCategory(string $category): array
    {
        if (! in_array($category, self::CATEGORIES, true)) return [];

        return Project::query()
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

        return Project::query()->where($category, $name)->exists();
    }

    private function categoryLabel(string $key): string
    {
        return match ($key) {
            'type' => 'Type',
            'status' => 'Status',
            default => $key,
        };
    }
}
