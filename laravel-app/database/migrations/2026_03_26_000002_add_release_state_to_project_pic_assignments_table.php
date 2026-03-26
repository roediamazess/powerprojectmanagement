<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('project_pic_assignments', function (Blueprint $table) {
            if (! Schema::hasColumn('project_pic_assignments', 'release_state')) {
                $table->string('release_state', 20)->default('Open')->after('status');
                $table->index(['release_state']);
            }
        });
    }

    public function down(): void
    {
        Schema::table('project_pic_assignments', function (Blueprint $table) {
            if (Schema::hasColumn('project_pic_assignments', 'release_state')) {
                $table->dropIndex(['release_state']);
                $table->dropColumn('release_state');
            }
        });
    }
};

