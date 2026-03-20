<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PartnerSetupOption extends Model
{
    protected $fillable = [
        'category',
        'name',
        'status',
    ];
}
