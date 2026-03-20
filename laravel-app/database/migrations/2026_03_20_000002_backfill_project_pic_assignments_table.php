<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (! DB::getSchemaBuilder()->hasTable('project_pic_assignments')) {
            return;
        }

        $rows = DB::table('projects')
            ->select(['id', 'pic_user_id', 'pic_name', 'pic_email', 'start_date', 'end_date'])
            ->whereNotNull('pic_user_id')
            ->get();

        foreach ($rows as $p) {
            $exists = DB::table('project_pic_assignments')->where('project_id', $p->id)->exists();
            if ($exists) continue;

            DB::table('project_pic_assignments')->insert([
                'project_id' => $p->id,
                'pic_user_id' => $p->pic_user_id,
                'pic_name' => $p->pic_name,
                'pic_email' => $p->pic_email,
                'start_date' => $p->start_date,
                'end_date' => $p->end_date,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
    }
};
