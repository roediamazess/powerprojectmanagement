<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->timestampTz('pickup_start_at')->nullable()->after('requirement_points');
            $table->timestampTz('pickup_end_at')->nullable()->after('pickup_start_at');

            $table->index('pickup_start_at');
            $table->index('pickup_end_at');
        });
    }

    public function down(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->dropIndex(['pickup_start_at']);
            $table->dropIndex(['pickup_end_at']);
            $table->dropColumn(['pickup_start_at', 'pickup_end_at']);
        });
    }
};

