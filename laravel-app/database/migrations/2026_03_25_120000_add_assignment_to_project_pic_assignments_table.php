<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('project_pic_assignments', function (Blueprint $table) {
            if (! Schema::hasColumn('project_pic_assignments', 'assignment')) {
                $table->string('assignment', 20)->nullable()->after('end_date');
                $table->index(['assignment']);
            }
        });
    }

    public function down(): void
    {
        Schema::table('project_pic_assignments', function (Blueprint $table) {
            if (Schema::hasColumn('project_pic_assignments', 'assignment')) {
                $table->dropIndex(['assignment']);
                $table->dropColumn('assignment');
            }
        });
    }
};

