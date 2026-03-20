<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('project_setup_options', function (Blueprint $table) {
            $table->id();
            $table->string('category', 50)->index();
            $table->string('name');
            $table->string('status', 20)->default('Active')->index();
            $table->timestamps();

            $table->unique(['category', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('project_setup_options');
    }
};
