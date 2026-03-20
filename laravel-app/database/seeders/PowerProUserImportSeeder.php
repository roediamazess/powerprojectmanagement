<?php

namespace Database\Seeders;

use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Role;

class PowerProUserImportSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = Tenant::query()->firstOrCreate(
            ['slug' => 'default'],
            ['name' => 'Default Tenant']
        );

        $rows = [
            ['name' => 'Akbar', 'full_name' => 'Fajar Achmad Akbar', 'email' => 'akbar@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '09/03/2017', 'birthday' => '02/12/1994'],
            ['name' => 'Aldi', 'full_name' => 'Rifaldi Hidayat', 'email' => 'aldi@powerpro.co.id', 'tier' => 'Tier 2', 'role' => 'User', 'status' => 'Active', 'start_work' => '13/08/2018', 'birthday' => '04/12/2025'],
            ['name' => 'Andreas', 'full_name' => 'Andreas Daniel Gunadi', 'email' => 'andreas@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => '31/03/2004'],
            ['name' => 'Apip', 'full_name' => 'Khairul Afip', 'email' => 'afip@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '20/01/2015', 'birthday' => '27/07/2016'],
            ['name' => 'Apri', 'full_name' => 'Muji Apriyanto', 'email' => 'muji@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '13/01/2014', 'birthday' => '05/04/2016'],
            ['name' => 'Arbi', 'full_name' => 'Arbiyanto Catur Wibisono', 'email' => 'arbi@powerpro.co.id', 'tier' => 'New Born', 'role' => 'User', 'status' => 'Active', 'start_work' => '30/06/2005', 'birthday' => null],
            ['name' => 'Aris', 'full_name' => 'Charisma Prima Wijaya', 'email' => 'aris@powerpro.co.id', 'tier' => 'Tier 2', 'role' => 'User', 'status' => 'Active', 'start_work' => '02/06/2016', 'birthday' => '15/07/1997'],
            ['name' => 'Basir', 'full_name' => 'Abdul Basir', 'email' => 'basir@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '17/12/2012', 'birthday' => null],
            ['name' => 'Bowo', 'full_name' => 'Ade Septiyan Nugroho', 'email' => 'bowo@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '22/03/2011', 'birthday' => '06/09/1991'],
            ['name' => 'Danang', 'full_name' => 'Danang Bagas Taranggono', 'email' => 'danang.bagas@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '03/05/2017', 'birthday' => '02/02/1995'],
            ['name' => 'Dhani', 'full_name' => 'Ahmad Adhani Nurrokhim', 'email' => 'dhani@powerpro.co.id', 'tier' => 'New Born', 'role' => 'User', 'status' => 'Active', 'start_work' => '30/01/2006', 'birthday' => null],
            ['name' => 'Dhika', 'full_name' => 'Andhika Hastungkoro', 'email' => 'dhika@powerpro.co.id', 'tier' => 'New Born', 'role' => 'User', 'status' => 'Active', 'start_work' => null, 'birthday' => null],
            ['name' => 'Fachri', 'full_name' => 'Fachri Huseini Muhammad', 'email' => 'fachri@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/01/2017', 'birthday' => '24/03/1994'],
            ['name' => 'Farhan', 'full_name' => 'Farhan Saputra', 'email' => 'farhan@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '24/10/2022', 'birthday' => null],
            ['name' => 'Hanip', 'full_name' => 'Hanipul Haqiqi', 'email' => 'hanip@powerpro.co.id', 'tier' => 'New Born', 'role' => 'User', 'status' => 'Active', 'start_work' => null, 'birthday' => null],
            ['name' => 'Hasbi', 'full_name' => 'M. Hasbiyanur', 'email' => 'hasbi@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '20/06/2013', 'birthday' => null],
            ['name' => 'Ichsan', 'full_name' => 'Muhammad Ichsan', 'email' => 'ichsan@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '25/10/2010', 'birthday' => null],
            ['name' => 'Ichwan', 'full_name' => 'Ichwan Noor Rachim', 'email' => 'ichwan@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '22/07/2011', 'birthday' => '17/05/1993'],
            ['name' => 'Ilham', 'full_name' => 'Ilham Adi Pramono', 'email' => 'ilham@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '08/01/2018', 'birthday' => '23/04/2018'],
            ['name' => 'Imam', 'full_name' => 'Imam Abdul Rakhman', 'email' => 'imam@powerpro.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '17/06/2011', 'birthday' => null],
            ['name' => 'Indra', 'full_name' => 'Indra Setiawan', 'email' => 'indra@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/07/2016', 'birthday' => null],
            ['name' => 'Iqhtiar', 'full_name' => 'Iqhtiar Aji Pangestu', 'email' => 'iqhtiar@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '24/10/2022', 'birthday' => null],
            ['name' => 'Jaja', 'full_name' => 'Jaja Suharja', 'email' => 'jaja@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/02/2018', 'birthday' => '16/09/1996'],
            ['name' => 'Komeng', 'full_name' => 'Rudianto', 'email' => 'pms@powerpro.id', 'tier' => 'Tier 3', 'role' => 'Administrator', 'status' => 'Active', 'start_work' => '05/04/2010', 'birthday' => null],
            ['name' => 'Lifi', 'full_name' => 'Ahlifi Nizali Aziz', 'email' => 'lifi@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '24/10/2022', 'birthday' => '01/04/2004'],
            ['name' => 'Mamat', 'full_name' => 'Rahmad Zaelani', 'email' => 'rahmad.zaelani@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '10/12/2014', 'birthday' => '28/08/2016'],
            ['name' => 'Mulya', 'full_name' => 'Mulya Darmaji', 'email' => 'mulya@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '17/10/2011', 'birthday' => null],
            ['name' => 'Naufal', 'full_name' => 'Raihan Alnaufal', 'email' => 'naufal@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => null],
            ['name' => 'Nur', 'full_name' => 'Fahmi Nur Ikram', 'email' => 'nur@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '24/10/2018', 'birthday' => null],
            ['name' => 'Prad', 'full_name' => 'Pradana Asih Widiyanto', 'email' => 'pradana@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => null],
            ['name' => 'Rafly', 'full_name' => 'Rafly Fauzy', 'email' => 'rafly@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => null],
            ['name' => 'Rama', 'full_name' => 'Rama Aditya', 'email' => 'rama@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '29/08/2016', 'birthday' => null],
            ['name' => 'Rey', 'full_name' => 'Raihan Zakaria Effendy', 'email' => 'rey@powerpro.co.id', 'tier' => 'New Born', 'role' => 'User', 'status' => 'Active', 'start_work' => null, 'birthday' => null],
            ['name' => 'Ridho', 'full_name' => 'Rafli Al Faridho', 'email' => 'ridho@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => '22/06/2004'],
            ['name' => 'Ridwan', 'full_name' => 'M. Ridwan', 'email' => 'ridwan@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '23/08/2012', 'birthday' => '26/08/2016'],
            ['name' => 'Rizky', 'full_name' => 'Muhamad Rizky', 'email' => 'rizky@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '31/01/2023', 'birthday' => null],
            ['name' => 'Robi', 'full_name' => 'Robi Kurniawan', 'email' => 'robi@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/12/2016', 'birthday' => null],
            ['name' => 'Sahrul', 'full_name' => "Sahrul Ahmad Safi'i", 'email' => 'sahrul@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '10/02/2014', 'birthday' => null],
            ['name' => 'Sodik', 'full_name' => 'Sodik Azhari', 'email' => 'sodek@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '29/01/2014', 'birthday' => '28/11/1995'],
            ['name' => 'Vincent', 'full_name' => 'Arya Vincent', 'email' => 'vincent@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '15/06/2016', 'birthday' => null],
            ['name' => 'Wahyudi', 'full_name' => 'Ilham Tri Wahyudi', 'email' => 'ilham.tri@powerpro.co.id', 'tier' => 'Tier 1', 'role' => 'User', 'status' => 'Active', 'start_work' => '24/10/2022', 'birthday' => null],
            ['name' => 'Widi', 'full_name' => 'Bayu Widiyanto', 'email' => 'widi@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '09/03/2017', 'birthday' => '07/01/1996'],
            ['name' => 'Yosa', 'full_name' => 'Yosa Kristian', 'email' => 'yosa@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '17/12/2012', 'birthday' => '15/05/1994'],
            ['name' => 'Yudi', 'full_name' => 'Muhammad Wahyudi', 'email' => 'wahyudi@powerpro.co.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/07/2016', 'birthday' => '04/01/1998'],
            ['name' => 'Ivan', 'full_name' => 'Irvan Verdiansyah', 'email' => 'irvan@powerpro.id', 'tier' => 'Tier 3', 'role' => 'User', 'status' => 'Active', 'start_work' => '26/03/2008', 'birthday' => null],
            ['name' => 'Tri', 'full_name' => 'Triono', 'email' => 'account.executive@powerpro.id', 'tier' => 'Tier 3', 'role' => 'Admin Officer', 'status' => 'Active', 'start_work' => null, 'birthday' => null],
            ['name' => 'Iam', 'full_name' => 'M. Ilham Rizki', 'email' => 'iam@powerpro.co.id', 'tier' => 'New Born', 'role' => 'Admin Officer', 'status' => 'Active', 'start_work' => null, 'birthday' => null],
        ];

        foreach ($rows as $row) {
            $roleName = $row['role'] ?? 'User';
            $role = Role::query()->firstOrCreate(['name' => $roleName, 'guard_name' => 'web']);

            $user = User::query()->updateOrCreate(
                ['email' => $row['email']],
                [
                    'tenant_id' => $tenant->id,
                    'is_internal' => $roleName !== 'Partner',
                    'name' => $row['name'] ?? '',
                    'full_name' => $row['full_name'] ?? null,
                    'password' => 'pps88',
                    'start_work' => $this->parseDate($row['start_work'] ?? null),
                    'birthday' => $this->parseDate($row['birthday'] ?? null),
                    'tier' => $row['tier'] ?? null,
                    'status' => $row['status'] ?? 'Active',
                    'email_verified_at' => now(),
                ]
            );

            $user->syncRoles([$role]);
        }
    }

    private function parseDate(?string $value): ?string
    {
        if (! $value) {
            return null;
        }

        $value = trim($value);
        if ($value === '') {
            return null;
        }

        try {
            return Carbon::createFromFormat('d/m/Y', $value)->toDateString();
        } catch (\Throwable) {
            return null;
        }
    }
}
