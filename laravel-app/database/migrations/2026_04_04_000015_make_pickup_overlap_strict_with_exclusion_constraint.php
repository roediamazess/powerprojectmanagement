<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        DB::statement('CREATE EXTENSION IF NOT EXISTS btree_gist');

        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->date('pickup_start_date')->nullable()->after('schedule_id');
            $table->date('pickup_end_date')->nullable()->after('pickup_start_date');
        });

        DB::statement('
            UPDATE arrangement_schedule_pickups p
            SET pickup_start_date = s.start_date,
                pickup_end_date = s.end_date
            FROM arrangement_schedules s
            WHERE s.id = p.schedule_id
              AND (p.pickup_start_date IS NULL OR p.pickup_end_date IS NULL)
        ');

        DB::statement('ALTER TABLE arrangement_schedule_pickups ALTER COLUMN pickup_start_date SET NOT NULL');
        DB::statement('ALTER TABLE arrangement_schedule_pickups ALTER COLUMN pickup_end_date SET NOT NULL');

        $overlapCount = (int) (DB::selectOne("
            SELECT COUNT(*) AS c
            FROM arrangement_schedule_pickups p1
            JOIN arrangement_schedule_pickups p2
              ON p1.user_id = p2.user_id
             AND p1.id < p2.id
             AND p1.status IN ('Picked','Released')
             AND p2.status IN ('Picked','Released')
             AND daterange(p1.pickup_start_date, p1.pickup_end_date, '[]')
                 && daterange(p2.pickup_start_date, p2.pickup_end_date, '[]')
        ")->c ?? 0);

        if ($overlapCount > 0) {
            throw new RuntimeException("Tidak bisa mengaktifkan aturan strict overlap: ditemukan {$overlapCount} pickup yang bentrok. Mohon perbaiki data terlebih dahulu.");
        }

        DB::statement("
            ALTER TABLE arrangement_schedule_pickups
            ADD COLUMN pickup_range daterange
            GENERATED ALWAYS AS (daterange(pickup_start_date, pickup_end_date, '[]')) STORED
        ");

        DB::statement("
            ALTER TABLE arrangement_schedule_pickups
            ADD CONSTRAINT arrangement_schedule_pickups_user_no_overlap
            EXCLUDE USING gist (
                user_id WITH =,
                pickup_range WITH &&
            )
            WHERE (status IN ('Picked', 'Released'))
        ");

        DB::statement('
            CREATE OR REPLACE FUNCTION arrangement_schedule_pickups_sync_dates()
            RETURNS trigger AS $$
            BEGIN
                SELECT start_date, end_date
                INTO NEW.pickup_start_date, NEW.pickup_end_date
                FROM arrangement_schedules
                WHERE id = NEW.schedule_id;

                IF NEW.pickup_start_date IS NULL OR NEW.pickup_end_date IS NULL THEN
                    RAISE EXCEPTION USING MESSAGE = \'Schedule not found for pickup\';
                END IF;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        ');

        DB::statement('DROP TRIGGER IF EXISTS trg_arrangement_pickups_sync_dates ON arrangement_schedule_pickups');
        DB::statement('
            CREATE TRIGGER trg_arrangement_pickups_sync_dates
            BEFORE INSERT OR UPDATE OF schedule_id
            ON arrangement_schedule_pickups
            FOR EACH ROW
            EXECUTE FUNCTION arrangement_schedule_pickups_sync_dates()
        ');

        DB::statement('
            CREATE OR REPLACE FUNCTION arrangement_schedules_propagate_dates_to_pickups()
            RETURNS trigger AS $$
            BEGIN
                UPDATE arrangement_schedule_pickups
                SET pickup_start_date = NEW.start_date,
                    pickup_end_date = NEW.end_date,
                    updated_at = NOW()
                WHERE schedule_id = NEW.id;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        ');

        DB::statement('DROP TRIGGER IF EXISTS trg_arrangement_schedules_propagate_dates_to_pickups ON arrangement_schedules');
        DB::statement('
            CREATE TRIGGER trg_arrangement_schedules_propagate_dates_to_pickups
            AFTER UPDATE OF start_date, end_date
            ON arrangement_schedules
            FOR EACH ROW
            EXECUTE FUNCTION arrangement_schedules_propagate_dates_to_pickups()
        ');
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        DB::statement('DROP TRIGGER IF EXISTS trg_arrangement_schedules_propagate_dates_to_pickups ON arrangement_schedules');
        DB::statement('DROP FUNCTION IF EXISTS arrangement_schedules_propagate_dates_to_pickups()');

        DB::statement('DROP TRIGGER IF EXISTS trg_arrangement_pickups_sync_dates ON arrangement_schedule_pickups');
        DB::statement('DROP FUNCTION IF EXISTS arrangement_schedule_pickups_sync_dates()');

        DB::statement('ALTER TABLE arrangement_schedule_pickups DROP CONSTRAINT IF EXISTS arrangement_schedule_pickups_user_no_overlap');
        DB::statement('ALTER TABLE arrangement_schedule_pickups DROP COLUMN IF EXISTS pickup_range');

        Schema::table('arrangement_schedule_pickups', function (Blueprint $table) {
            $table->dropColumn(['pickup_start_date', 'pickup_end_date']);
        });
    }
};
