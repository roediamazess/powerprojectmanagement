<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->unsignedSmallInteger('min_requirement_points')->default(0)->after('name');
            $table->unsignedSmallInteger('max_requirement_points')->default(0)->after('min_requirement_points');

            $table->index('min_requirement_points');
            $table->index('max_requirement_points');
        });

        DB::statement('UPDATE arrangement_batches SET max_requirement_points = requirement_points WHERE max_requirement_points = 0');
    }

    public function down(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->dropIndex(['min_requirement_points']);
            $table->dropIndex(['max_requirement_points']);
            $table->dropColumn(['min_requirement_points', 'max_requirement_points']);
        });
    }
};

