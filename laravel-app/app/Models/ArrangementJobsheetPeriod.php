<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class ArrangementJobsheetPeriod extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $table = 'arrangement_jobsheet_periods';

    protected $fillable = [
        'id',
        'name',
        'start_date',
        'end_date',
        'created_by',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'created_by' => 'integer',
    ];

    protected static function booted(): void
    {
        static::creating(function (ArrangementJobsheetPeriod $period) {
            if (! $period->getKey()) {
                $period->setAttribute($period->getKeyName(), (string) Str::uuid());
            }
        });
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
