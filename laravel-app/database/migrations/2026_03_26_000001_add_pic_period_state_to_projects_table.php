<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            if (Schema::hasColumn('projects', 'pic_period_state')) {
                return;
            }

            $table->string('pic_period_state', 20)->default('Open')->after('pic_assignment');
            $table->index(['pic_period_state']);
        });
    }

    public function down(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            if (! Schema::hasColumn('projects', 'pic_period_state')) {
                return;
            }

            $table->dropIndex(['pic_period_state']);
            $table->dropColumn('pic_period_state');
        });
    }
};

