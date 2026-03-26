<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('project_pic_assignments')) {
            DB::statement("UPDATE project_pic_assignments SET assignment = 'Assignment' WHERE assignment IS NULL OR assignment = ''");
        }
    }

    public function down(): void
    {
        // no-op
    }
};

