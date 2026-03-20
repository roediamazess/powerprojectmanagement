<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_setup_options', function (Blueprint $table) {
            $table->id();
            $table->string('category', 50);
            $table->string('name', 255);
            $table->timestamps();

            $table->unique(['category', 'name']);
            $table->index(['category']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_setup_options');
    }
};
