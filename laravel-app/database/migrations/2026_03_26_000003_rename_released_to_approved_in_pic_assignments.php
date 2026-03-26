<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('project_pic_assignments')) {
            DB::statement("update project_pic_assignments set release_state='Approved' where release_state='Released'");
        }
        if (Schema::hasTable('projects')) {
            DB::statement("update projects set pic_period_state='Approved' where pic_period_state='Released'");
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('project_pic_assignments')) {
            DB::statement("update project_pic_assignments set release_state='Released' where release_state='Approved'");
        }
        if (Schema::hasTable('projects')) {
            DB::statement("update projects set pic_period_state='Released' where pic_period_state='Approved'");
        }
    }
};

