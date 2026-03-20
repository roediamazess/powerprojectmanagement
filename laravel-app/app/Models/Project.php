<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Project extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'cnc_id',
        'pic_user_id',
        'pic_name',
        'pic_email',
        'partner_id',
        'partner_name',
        'project_name',
        'assignment',
        'project_information',
        'pic_assignment',
        'type',
        'start_date',
        'end_date',
        'total_days',
        'status',
        'handover_official_report',
        'handover_days',
        'kpi2_pic',
        'check_official_report',
        'check_days',
        'kpi2_officer',
        'point_ach',
        'point_req',
        'percentage_of_point',
        'validation_date',
        'validation_days',
        'kpi2_okr',
        'spreadsheet_id',
        'spreadsheet_url',
        'activity_sent',
        's1_estimation_date',
        's1_over_days',
        's1_count_emails_sent',
        's2_email_sent',
        's3_email_sent',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'handover_official_report' => 'date',
        'check_official_report' => 'date',
        'validation_date' => 'date',
        'activity_sent' => 'datetime',
        's1_estimation_date' => 'date',
        'total_days' => 'integer',
        'handover_days' => 'integer',
        'validation_days' => 'integer',
        'point_ach' => 'integer',
        'point_req' => 'integer',
        'percentage_of_point' => 'decimal:2',
    ];

    protected static function booted(): void
    {
        static::creating(function (Project $project) {
            if (! $project->getKey()) {
                $project->setAttribute($project->getKeyName(), (string) Str::uuid());
            }
        });
    }


    public function picAssignments(): HasMany
    {
        return $this->hasMany(ProjectPicAssignment::class);
    }

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class);
    }

    public function picUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'pic_user_id');
    }
}
