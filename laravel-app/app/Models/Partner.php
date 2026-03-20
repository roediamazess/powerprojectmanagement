<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Partner extends Model
{
    protected $fillable = [
        'cnc_id',
        'name',
        'star',
        'room',
        'outlet',
        'status',
        'system_live',
        'implementation_type',
        'system_version',
        'type',
        'group',
        'address',
        'area',
        'sub_area',
        'gm_email',
        'fc_email',
        'ca_email',
        'cc_email',
        'ia_email',
        'it_email',
        'hrd_email',
        'fom_email',
        'dos_email',
        'ehk_email',
        'fbm_email',
        'last_visit',
        'last_visit_type',
        'last_project',
        'last_project_type',
    ];

    protected $casts = [
        'system_live' => 'date',
        'last_visit' => 'date',
        'star' => 'integer',
    ];
}
