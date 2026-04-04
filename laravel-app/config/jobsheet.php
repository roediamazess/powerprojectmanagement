<?php

return [
    'holidays' => array_values(array_filter(array_map('trim', explode(',', (string) env('JOBSHEET_HOLIDAYS', ''))))),
];

