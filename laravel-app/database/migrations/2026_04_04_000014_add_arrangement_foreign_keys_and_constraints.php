<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->foreign('created_by')->references('id')->on('users')->restrictOnDelete();
        });

        Schema::table('arrangement_schedules', function (Blueprint $table) {
            $table->foreign('batch_id')->references('id')->on('arrangement_batches')->nullOnDelete();
            $table->foreign('created_by')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('approved_by')->references('id')->on('users')->nullOnDelete();
        });

        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->foreign('schedule_id')->references('id')->on('arrangement_schedules')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->restrictOnDelete();
            $table->index(['user_id', 'status']);
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE arrangement_batches ADD CONSTRAINT arrangement_batches_status_check CHECK (status IN ('Open','Approved'))");
            DB::statement('ALTER TABLE arrangement_batches ADD CONSTRAINT arrangement_batches_points_check CHECK (min_requirement_points <= max_requirement_points)');
            DB::statement("ALTER TABLE arrangement_schedule_pickups ADD CONSTRAINT arrangement_schedule_pickups_status_check CHECK (status IN ('Picked','Released'))");
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE arrangement_schedule_pickups DROP CONSTRAINT IF EXISTS arrangement_schedule_pickups_status_check');
            DB::statement('ALTER TABLE arrangement_batches DROP CONSTRAINT IF EXISTS arrangement_batches_points_check');
            DB::statement('ALTER TABLE arrangement_batches DROP CONSTRAINT IF EXISTS arrangement_batches_status_check');
        }

        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->dropIndex(['user_id', 'status']);
            $table->dropForeign(['schedule_id']);
            $table->dropForeign(['user_id']);
        });

        Schema::table('arrangement_schedules', function (Blueprint $table) {
            $table->dropForeign(['batch_id']);
            $table->dropForeign(['created_by']);
            $table->dropForeign(['approved_by']);
        });

        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->dropForeign(['created_by']);
        });
    }
};
