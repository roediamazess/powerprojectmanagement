<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('arrangement_jobsheet_periods', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name', 120);
            $table->date('start_date');
            $table->date('end_date');
            $table->unsignedBigInteger('created_by');
            $table->timestamps();

            $table->index('created_by');
            $table->index(['start_date', 'end_date']);

            $table->foreign('created_by')->references('id')->on('users')->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('arrangement_jobsheet_periods');
    }
};
