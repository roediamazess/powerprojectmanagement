<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('project_pic_assignments') && Schema::hasColumn('project_pic_assignments', 'status')) {
            DB::statement("UPDATE project_pic_assignments SET status = 'Scheduled' WHERE status IS NULL OR status = ''");
        }
    }

    public function down(): void
    {
    }
};

