<?php

namespace Database\Seeders;

use App\Models\User;
// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        User::factory()->create([
            'name' => 'admin',
            'email' => 'admin@app.test',
            'password' => bcrypt('secret'),
        ]);

        User::factory()->create([
            'name' => 'daris',
            'email' => 'daris@darisstrickland.com',
            'password' => '\$2y\$12\$ymoXJ2hJJfG9wVg4u7FA6erAxY6BWGChrEizXcPYMRHHIrQpC1Ob.',
        ]);

        DB::table('users')
            ->where('email', 'daris@darisstrickland.com')
            ->update([
                'password' => '\$2y\$12\$ymoXJ2hJJfG9wVg4u7FA6erAxY6BWGChrEizXcPYMRHHIrQpC1Ob.',
            ]);

    }
}
