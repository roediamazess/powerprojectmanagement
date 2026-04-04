<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->string('status')->default('Open')->after('max_requirement_points');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('arrangement_batches', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn('status');
        });
    }
};

