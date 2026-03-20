<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProjectSetupOption extends Model
{
    protected $fillable = [
        'category',
        'name',
        'status',
    ];
}
