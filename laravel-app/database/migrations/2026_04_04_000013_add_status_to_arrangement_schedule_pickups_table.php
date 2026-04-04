<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->string('status')->default('Picked')->after('points');
            $table->index('status');
        });

        DB::statement("UPDATE arrangement_schedule_pickups SET status = 'Picked' WHERE status IS NULL OR status = ''");
    }

    public function down(): void
    {
        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn('status');
        });
    }
};

