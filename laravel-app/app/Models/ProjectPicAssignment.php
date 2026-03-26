<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProjectPicAssignment extends Model
{
    protected $fillable = [
        'project_id',
        'pic_user_id',
        'pic_name',
        'pic_email',
        'start_date',
        'end_date',
        'assignment',
        'status',
        'release_state',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
    ];

    public function project(): BelongsTo
    {
        return $this->belongsTo(Project::class);
    }

    public function picUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'pic_user_id');
    }
}
