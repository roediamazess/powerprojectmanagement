<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        if (! Schema::hasTable('projects') || ! Schema::hasColumn('projects', 'no')) {
            return;
        }

        DB::statement("CREATE SEQUENCE IF NOT EXISTS projects_no_seq START 1 INCREMENT 1");

        DB::statement(<<<'SQL'
DO $$
DECLARE v_max bigint;
BEGIN
  SELECT MAX(no) INTO v_max FROM projects;
  IF v_max IS NULL THEN
    PERFORM setval('projects_no_seq', 1, false);
  ELSE
    PERFORM setval('projects_no_seq', v_max, true);
  END IF;
END $$;
SQL);
    }

    public function down(): void
    {
    }
};

