<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('full_name')->nullable()->after('name');
            $table->date('start_work')->nullable()->after('password');
            $table->date('birthday')->nullable()->after('start_work');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['full_name', 'start_work', 'birthday']);
        });
    }
};
