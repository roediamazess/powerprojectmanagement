<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('projects', function (Blueprint $table) {
            $table->uuid('id')->primary();

            $table->string('cnc_id', 50)->nullable();

            $table->foreignId('pic_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('pic_name')->nullable();
            $table->string('pic_email')->nullable();

            $table->foreignId('partner_id')->nullable()->constrained('partners')->nullOnDelete();
            $table->string('partner_name')->nullable();

            $table->text('project_name')->nullable();

            $table->string('assignment', 20)->nullable();
            $table->string('project_information', 20)->default('Submission');
            $table->string('pic_assignment', 20)->default('Request');

            $table->string('type')->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->integer('total_days')->nullable();
            $table->string('status')->nullable();

            $table->date('handover_official_report')->nullable();
            $table->integer('handover_days')->nullable();

            $table->text('kpi2_pic')->nullable();

            $table->date('check_official_report')->nullable();
            $table->text('check_days')->nullable();
            $table->text('kpi2_officer')->nullable();

            $table->integer('point_ach')->nullable();
            $table->integer('point_req')->nullable();
            $table->decimal('percentage_of_point', 6, 2)->nullable();

            $table->date('validation_date')->nullable();
            $table->integer('validation_days')->nullable();

            $table->text('kpi2_okr')->nullable();

            $table->text('spreadsheet_id')->nullable();
            $table->text('spreadsheet_url')->nullable();

            $table->timestamp('activity_sent')->nullable();

            $table->date('s1_estimation_date')->nullable();
            $table->text('s1_over_days')->nullable();
            $table->text('s1_count_emails_sent')->nullable();
            $table->text('s2_email_sent')->nullable();
            $table->text('s3_email_sent')->nullable();

            $table->timestamps();

            $table->index(['partner_id']);
            $table->index(['pic_user_id']);
            $table->index(['type']);
            $table->index(['status']);
            $table->index(['start_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('projects');
    }
};
