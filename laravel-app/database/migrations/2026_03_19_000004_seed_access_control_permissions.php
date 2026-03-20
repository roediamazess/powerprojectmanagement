<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use App\Support\PermissionCatalog;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('permissions') || ! Schema::hasTable('roles')) {
            return;
        }

        foreach (PermissionCatalog::allPermissionKeys() as $name) {
            Permission::query()->firstOrCreate(['name' => $name, 'guard_name' => 'web']);
        }

        $admin = Role::query()->firstOrCreate(['name' => 'Administrator', 'guard_name' => 'web']);
        $admin->syncPermissions(PermissionCatalog::allPermissionKeys());

        $partnerAdmin = Role::query()->firstOrCreate(['name' => 'Partner Admin', 'guard_name' => 'web']);
        $partnerAdmin->syncPermissions([
            'partners.view',
            'partners.create',
            'partners.update',
            'partners.delete',
            'partner_setup.view',
            'partner_setup.create',
            'partner_setup.update',
            'partner_setup.delete',
        ]);
    }

    public function down(): void
    {
        // no-op
    }
};
