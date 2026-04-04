<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class ArrangementBatch extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'name',
        'requirement_points',
        'min_requirement_points',
        'max_requirement_points',
        'status',
        'pickup_start_at',
        'pickup_end_at',
        'created_by',
    ];

    protected $casts = [
        'requirement_points' => 'integer',
        'min_requirement_points' => 'integer',
        'max_requirement_points' => 'integer',
        'pickup_start_at' => 'datetime',
        'pickup_end_at' => 'datetime',
    ];

    public function schedules(): HasMany
    {
        return $this->hasMany(ArrangementSchedule::class, 'batch_id');
    }

    protected static function booted(): void
    {
        static::creating(function (ArrangementBatch $batch) {
            if (! $batch->getKey()) {
                $batch->setAttribute($batch->getKeyName(), (string) Str::uuid());
            }

            if (! $batch->getAttribute('max_requirement_points') && $batch->getAttribute('requirement_points')) {
                $batch->setAttribute('max_requirement_points', (int) $batch->getAttribute('requirement_points'));
            }

            if ($batch->getAttribute('min_requirement_points') === null) {
                $batch->setAttribute('min_requirement_points', 0);
            }
        });
    }
}
