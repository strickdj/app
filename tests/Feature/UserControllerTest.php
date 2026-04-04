<?php

use App\Models\User;
use Inertia\Testing\AssertableInertia;

test('authenticated users can visit the users page', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]))
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->component('Users')
            ->has('users')
            ->has('users.data')
            ->has('filters')
        );
});

test('search filter returns users that match by name', function (): void {
    $user = User::factory()->create();

    User::factory()->create([
        'name' => 'SearchCase Alice',
        'email' => 'alice-search@example.test',
    ]);

    User::factory()->create([
        'name' => 'SearchCase Bob',
        'email' => 'bob-search@example.test',
    ]);

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?filter[search]=SearchCase Alice')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->has('users.data', 1)
            ->where('users.data.0.name', 'SearchCase Alice')
        );
});

test('search filter returns users that match by email', function (): void {
    $user = User::factory()->create();

    User::factory()->create([
        'name' => 'EmailCase Alpha',
        'email' => 'alpha-email@example.test',
    ]);

    User::factory()->create([
        'name' => 'EmailCase Beta',
        'email' => 'beta-email@example.test',
    ]);

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?filter[search]=beta-email')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->has('users.data', 1)
            ->where('users.data.0.email', 'beta-email@example.test')
        );
});

test('sort name ascending returns expected order for filtered set', function (): void {
    $user = User::factory()->create();

    User::factory()->create(['name' => 'SortCase Charlie']);
    User::factory()->create(['name' => 'SortCase Alpha']);
    User::factory()->create(['name' => 'SortCase Bravo']);

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?filter[search]=SortCase&sort=name')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->where('users.data.0.name', 'SortCase Alpha')
            ->where('users.data.1.name', 'SortCase Bravo')
            ->where('users.data.2.name', 'SortCase Charlie')
        );
});

test('sort name descending returns expected order for filtered set', function (): void {
    $user = User::factory()->create();

    User::factory()->create(['name' => 'SortCase Charlie']);
    User::factory()->create(['name' => 'SortCase Alpha']);
    User::factory()->create(['name' => 'SortCase Bravo']);

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?filter[search]=SortCase&sort=-name')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->where('users.data.0.name', 'SortCase Charlie')
            ->where('users.data.1.name', 'SortCase Bravo')
            ->where('users.data.2.name', 'SortCase Alpha')
        );
});

test('filters prop is normalized for frontend consumption', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?filter[search]=abc&sort=-email&page[size]=25')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->where('filters.search', 'abc')
            ->where('filters.sort', 'email')
            ->where('filters.direction', 'desc')
            ->where('filters.per_page', 25)
        );
});
