<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partners', function (Blueprint $table) {
            $table->id();
            $table->string('cnc_id', 50)->unique();
            $table->string('name', 255);
            $table->unsignedTinyInteger('star')->nullable();
            $table->string('room', 50)->nullable();
            $table->string('outlet', 50)->nullable();
            $table->string('status', 20)->default('Active');
            $table->date('system_live')->nullable();

            $table->string('implementation_type', 255)->nullable();
            $table->string('system_version', 255)->nullable();
            $table->string('type', 255)->nullable();
            $table->string('group', 255)->nullable();
            $table->text('address')->nullable();
            $table->string('area', 255)->nullable();
            $table->string('sub_area', 255)->nullable();

            $table->string('gm_email', 255)->nullable();
            $table->string('fc_email', 255)->nullable();
            $table->string('ca_email', 255)->nullable();
            $table->string('cc_email', 255)->nullable();
            $table->string('ia_email', 255)->nullable();
            $table->string('it_email', 255)->nullable();
            $table->string('hrd_email', 255)->nullable();
            $table->string('fom_email', 255)->nullable();
            $table->string('dos_email', 255)->nullable();
            $table->string('ehk_email', 255)->nullable();
            $table->string('fbm_email', 255)->nullable();

            $table->date('last_visit')->nullable();
            $table->string('last_visit_type', 255)->nullable();
            $table->string('last_project', 255)->nullable();
            $table->string('last_project_type', 255)->nullable();

            $table->timestamps();

            $table->index(['status']);
            $table->index(['star']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partners');
    }
};
