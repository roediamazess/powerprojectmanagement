<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('release_notes')) {
            return;
        }

        $row = DB::table('release_notes')->where('version', 'v1.2603.5')->first();
        if (! $row) {
            return;
        }

        $data = json_decode($row->data ?? '{}', true) ?: [];
        $sections = $data['sections'] ?? [];
        if (! is_array($sections)) {
            return;
        }

        $wrapCode = function (string $text): string {
            $t = trim($text);
            if ($t === '') return $t;
            if (str_contains($t, '`')) return $t;
            return "`{$t}`";
        };

        foreach ($sections as &$sec) {
            if (! isset($sec['references']) || ! is_array($sec['references'])) continue;

            $nextRefs = [];
            foreach ($sec['references'] as $ref) {
                $text = (string) ($ref ?? '');
                if ($text === '') continue;

                if (str_contains($text, '`')) {
                    $nextRefs[] = $text;
                    continue;
                }

                $idx = strpos($text, ':');
                if ($idx === false) {
                    $nextRefs[] = $wrapCode($text);
                    continue;
                }

                $prefix = trim(substr($text, 0, $idx + 1));
                $suffix = trim(substr($text, $idx + 1));
                $parts = array_values(array_filter(array_map('trim', explode(',', $suffix)), fn ($p) => $p !== ''));

                if (count($parts) === 0) {
                    $nextRefs[] = $text;
                    continue;
                }

                $parts = array_map($wrapCode, $parts);
                $nextRefs[] = $prefix . ' ' . implode(', ', $parts);
            }

            $sec['references'] = $nextRefs;
        }
        unset($sec);

        DB::table('release_notes')
            ->where('id', $row->id)
            ->update([
                'data' => json_encode(['sections' => $sections]),
                'updated_at' => now(),
            ]);
    }

    public function down(): void
    {
    }
};

