<?php

namespace App\Http\Controllers\Examples;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Example;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

/**
 * CONTOH IDEAL CONTROLLER (LEVEL 3)
 * - Menggunakan Inertia.js untuk rendering
 * - Implementasi Audit Logging di setiap transaksi
 * - Validasi request yang ketat
 * - Mapping data paginator untuk keamanan (tidak expose semua kolom DB)
 */
class ExampleController extends Controller
{
    public function index(Request $request): Response
    {
        // 1. Query builder dengan filter tenant_id (Level 1)
        $query = Example::query()
            ->where('tenant_id', $request->user()->tenant_id)
            ->orderBy('id', 'desc');

        // 2. Pagination & Mapping
        $items = $query->paginate(50)->through(fn ($item) => [
            'id' => $item->id,
            'name' => $item->name,
            'status' => $item->status,
            'created_at' => $item->created_at->toDateString(),
        ]);

        return Inertia::render('Examples/Index', [
            'items' => $items,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'status' => 'required|in:Active,Inactive',
        ]);

        // Auto-assign tenant_id
        $data['tenant_id'] = $request->user()->tenant_id;

        DB::transaction(function () use ($request, $data) {
            $item = Example::create($data);
            
            // 3. Audit Logging (Level 1)
            AuditLog::record($request, 'create', Example::class, (string) $item->id, null, $item->toArray());
        });

        return redirect()->back()->with('success', 'Data berhasil dibuat');
    }
}
