<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('project_pic_assignments', function (Blueprint $table) {
            $table->id();
            $table->uuid('project_id');

            $table->foreignId('pic_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('pic_name')->nullable();
            $table->string('pic_email')->nullable();

            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();

            $table->timestamps();

            $table->foreign('project_id')->references('id')->on('projects')->cascadeOnDelete();
            $table->index(['project_id']);
            $table->index(['pic_user_id']);
            $table->index(['start_date']);
            $table->index(['end_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('project_pic_assignments');
    }
};
