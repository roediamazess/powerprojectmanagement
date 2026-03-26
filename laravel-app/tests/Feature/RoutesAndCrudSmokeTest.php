<?php

namespace Tests\Feature;

use App\Models\Partner;
use App\Models\TimeBoxing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class RoutesAndCrudSmokeTest extends TestCase
{
    use RefreshDatabase;

    private function actingAsAdmin()
    {
        $user = User::factory()->create();
        $admin = Role::query()->firstOrCreate(['name' => 'Administrator', 'guard_name' => 'web']);
        $user->syncRoles([$admin]);
        $this->actingAs($user);
        return $user;
    }

    public function test_partners_crud_routes_and_db_updates(): void
    {
        $this->actingAsAdmin();

        $this->get('/partners')->assertStatus(200);

        $resp = $this->post('/partners', [
            'cnc_id' => 'CNC-SMOKE-001',
            'name' => 'Smoke Partner',
            'status' => 'Active',
        ]);
        $resp->assertRedirectToRoute('partners.index');
        $this->assertDatabaseHas('partners', ['cnc_id' => 'CNC-SMOKE-001', 'name' => 'Smoke Partner']);

        $partner = Partner::query()->where('cnc_id', 'CNC-SMOKE-001')->firstOrFail();
        $resp = $this->put("/partners/{$partner->id}", [
            'cnc_id' => 'CNC-SMOKE-001',
            'name' => 'Smoke Partner Updated',
            'status' => 'Active',
        ]);
        $resp->assertRedirectToRoute('partners.index');
        $this->assertDatabaseHas('partners', ['id' => $partner->id, 'name' => 'Smoke Partner Updated']);

        $resp = $this->delete("/partners/{$partner->id}");
        $resp->assertRedirectToRoute('partners.index');
        $this->assertDatabaseMissing('partners', ['id' => $partner->id]);
    }

    public function test_projects_crud_routes_and_db_updates(): void
    {
        $this->actingAsAdmin();

        // Seed minimal setup options
        DB::table('project_setup_options')->insert([
            ['category' => 'type', 'name' => 'Maintenance', 'status' => 'Active'],
            ['category' => 'status', 'name' => 'Scheduled', 'status' => 'Active'],
        ]);

        $this->get('/projects')->assertStatus(200);

        $partner = Partner::query()->create([
            'cnc_id' => 'CNC-PROJ-001',
            'name' => 'Project Partner',
            'status' => 'Active',
        ]);
        $pic = User::factory()->create();

        $resp = $this->post('/projects', [
            'partner_id' => $partner->id,
            'cnc_id' => 'CNC-TEST-004',
            'project_name' => 'Smoke Project Create',
            'assignment' => 'Leader',
            'project_information' => 'Submission',
            'pic_assignment' => 'Request',
            'pic_period_state' => 'Open',
            'type' => 'Maintenance',
            'status' => 'Scheduled',
            'start_date' => '2026-03-01',
            'end_date' => '2026-03-10',
            'spreadsheet_id' => 'ACT-001',
            'spreadsheet_url' => 'https://example.test/activity/1',
            'activity_sent' => '2026-03-02',
            'handover_official_report' => '2026-03-10',
            'kpi2_pic' => 'PIC KPI',
            'point_ach' => 10,
            'point_req' => 20,
            'check_official_report' => '2026-03-12',
            'check_days' => '2',
            'kpi2_officer' => 'Officer KPI',
            'validation_date' => '2026-03-15',
            'kpi2_okr' => 'OKR KPI',
            's1_estimation_date' => '2026-03-20',
            's1_over_days' => '1',
            's1_count_emails_sent' => '3',
            's2_email_sent' => '2026-03-21',
            's3_email_sent' => '2026-03-22',
            'pic_assignments' => [
                [
                    'pic_user_id' => $pic->id,
                    'start_date' => '2026-03-01',
                    'end_date' => '2026-03-05',
                    'status' => 'Running',
                ],
            ],
        ]);
        $resp->assertRedirectToRoute('projects.index');
        $this->assertDatabaseHas('projects', ['type' => 'Maintenance', 'status' => 'Scheduled', 'project_name' => 'Smoke Project Create']);

        $project = DB::table('projects')->orderByDesc('id')->first();
        $assignmentId = DB::table('project_pic_assignments')->where('project_id', $project->id)->value('id');
        $this->assertDatabaseHas('project_pic_assignments', [
            'project_id' => $project->id,
            'pic_user_id' => $pic->id,
            'status' => 'Running',
        ]);

        // Set row to Approved (per-row lock)
        $resp = $this->put("/projects/{$project->id}", [
            'project_information' => 'Submission',
            'pic_assignment' => 'Request',
            'type' => 'Maintenance',
            'status' => 'Scheduled',
            'project_name' => 'Smoke Project Create',
            'start_date' => '2026-03-01',
            'end_date' => '2026-03-10',
            'pic_assignments' => [
                [
                    'id' => $assignmentId,
                    'pic_user_id' => $pic->id,
                    'start_date' => '2026-03-01',
                    'end_date' => '2026-03-05',
                    'status' => 'Running',
                    'release_state' => 'Approved',
                ],
            ],
        ]);
        $resp->assertRedirectToRoute('projects.index');

        // Change Status on Approved row → allowed
        $resp = $this->put("/projects/{$project->id}", [
            'project_information' => 'Submission',
            'pic_assignment' => 'Request',
            'type' => 'Maintenance',
            'status' => 'Scheduled',
            'project_name' => 'Smoke Project Create',
            'start_date' => '2026-03-01',
            'end_date' => '2026-03-10',
            'pic_assignments' => [
                [
                    'id' => $assignmentId,
                    'pic_user_id' => $pic->id,
                    'start_date' => '2026-03-01',
                    'end_date' => '2026-03-05',
                    'status' => 'Done',
                    'release_state' => 'Approved',
                ],
            ],
        ]);
        $this->assertDatabaseHas('project_pic_assignments', [
            'project_id' => $project->id,
            'pic_user_id' => $pic->id,
            'status' => 'Done',
        ]);

        // Change Beginning on Approved row → should error
        $resp = $this->put("/projects/{$project->id}", [
            'project_information' => 'Submission',
            'pic_assignment' => 'Request',
            'type' => 'Maintenance',
            'status' => 'Scheduled',
            'project_name' => 'Smoke Project Create',
            'start_date' => '2026-03-01',
            'end_date' => '2026-03-10',
            'pic_assignments' => [
                [
                    'id' => $assignmentId,
                    'pic_user_id' => $pic->id,
                    'start_date' => '2026-03-02',
                    'end_date' => '2026-03-05',
                    'status' => 'Done',
                    'release_state' => 'Approved',
                ],
            ],
        ]);
        $resp->assertStatus(302);
        $resp->assertSessionHasErrors(['pic_assignments']);
        $this->assertDatabaseHas('project_pic_assignments', [
            'project_id' => $project->id,
            'id' => $assignmentId,
            'status' => 'Done',
        ]);

        $resp = $this->put("/projects/{$project->id}", [
            'project_information' => 'Submission',
            'pic_assignment' => 'Request',
            'type' => 'Maintenance',
            'status' => 'Scheduled',
            'project_name' => 'Smoke Project',
            'start_date' => '2026-03-01',
            'end_date' => '2026-03-10',
            'pic_assignments' => [
                [
                    'id' => $assignmentId,
                    'pic_user_id' => $pic->id,
                    'start_date' => '2026-03-01',
                    'end_date' => '2026-03-05',
                    'status' => 'Done',
                    'release_state' => 'Open',
                ],
            ],
        ]);
        $resp->assertRedirectToRoute('projects.index');
        $this->assertDatabaseHas('projects', ['id' => $project->id, 'project_name' => 'Smoke Project']);
        $this->assertDatabaseHas('project_pic_assignments', [
            'project_id' => $project->id,
            'pic_user_id' => $pic->id,
            'status' => 'Done',
        ]);

        $resp = $this->delete("/projects/{$project->id}");
        $resp->assertRedirectToRoute('projects.index');
        $this->assertDatabaseMissing('projects', ['id' => $project->id]);
        $this->assertDatabaseMissing('project_pic_assignments', ['project_id' => $project->id]);
    }

    public function test_time_boxing_crud_routes_and_db_updates(): void
    {
        $this->actingAsAdmin();

        // Seed minimal setup options
        DB::table('time_boxing_setup_options')->insert([
            ['category' => 'type', 'name' => 'General', 'status' => 'Active'],
        ]);

        $this->get('/time-boxing')->assertStatus(200);

        $resp = $this->post('/time-boxing', [
            'information_date' => now()->toDateString(),
            'type' => 'General',
            'priority' => 'Normal',
            'status' => 'Brain Dump',
            'description' => 'Smoke create',
        ]);
        $resp->assertStatus(302);
        $this->assertDatabaseHas('time_boxings', ['description' => 'Smoke create']);

        $tb = TimeBoxing::query()->orderByDesc('id')->firstOrFail();
        $resp = $this->put("/time-boxing/{$tb->id}", [
            'information_date' => now()->toDateString(),
            'type' => 'General',
            'priority' => 'Normal',
            'status' => 'Priority List',
            'description' => 'Smoke update',
        ]);
        $resp->assertStatus(302);
        $this->assertDatabaseHas('time_boxings', ['id' => $tb->id, 'description' => 'Smoke update', 'status' => 'Priority List']);

        $resp = $this->delete("/time-boxing/{$tb->id}");
        $resp->assertStatus(302);
        $this->assertDatabaseMissing('time_boxings', ['id' => $tb->id]);
    }

    public function test_audit_logs_route_available(): void
    {
        $this->actingAsAdmin();
        $this->get('/audit-logs')->assertStatus(200);
    }
}
