<?php

use App\Enums\TeamRole;
use App\Models\Team;
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

test('requested page number is applied to paginated users results', function (): void {
    $user = User::factory()->create();

    User::factory()->count(25)->create();

    $this->actingAs($user)
        ->get(route('users', ['current_team' => $user->currentTeam]).'?page[size]=10&page[number]=2')
        ->assertOk()
        ->assertInertia(fn (AssertableInertia $page) => $page
            ->where('users.current_page', 2)
            ->has('users.data', 10)
            ->where('filters.page', 2)
            ->where('filters.per_page', 10)
        );
});

test('owners can bulk delete selected users', function (): void {
    $user = User::factory()->create();
    $usersToDelete = User::factory()->count(2)->create();

    $response = $this
        ->actingAs($user)
        ->delete(route('users.bulk-destroy', ['current_team' => $user->currentTeam]), [
            'user_ids' => $usersToDelete->pluck('id')->all(),
        ]);

    $response->assertRedirect();

    $usersToDelete->each(function (User $userToDelete): void {
        $this->assertDatabaseMissing('users', ['id' => $userToDelete->id]);
    });

    $this->assertDatabaseHas('users', ['id' => $user->id]);
});

test('bulk delete requires at least one selected user id', function (): void {
    $user = User::factory()->create();

    $response = $this
        ->actingAs($user)
        ->from(route('users', ['current_team' => $user->currentTeam]))
        ->delete(route('users.bulk-destroy', ['current_team' => $user->currentTeam]), [
            'user_ids' => [],
        ]);

    $response
        ->assertRedirect(route('users', ['current_team' => $user->currentTeam]))
        ->assertSessionHasErrors('user_ids');
});

test('bulk delete cannot include the authenticated user', function (): void {
    $user = User::factory()->create();
    $otherUser = User::factory()->create();

    $response = $this
        ->actingAs($user)
        ->from(route('users', ['current_team' => $user->currentTeam]))
        ->delete(route('users.bulk-destroy', ['current_team' => $user->currentTeam]), [
            'user_ids' => [$user->id, $otherUser->id],
        ]);

    $response
        ->assertRedirect(route('users', ['current_team' => $user->currentTeam]))
        ->assertSessionHasErrors('user_ids');

    $this->assertDatabaseHas('users', ['id' => $user->id]);
    $this->assertDatabaseHas('users', ['id' => $otherUser->id]);
});

test('team members without permission cannot bulk delete users', function (): void {
    $owner = User::factory()->create();
    $member = User::factory()->create();
    $targetUser = User::factory()->create();

    $team = $owner->currentTeam;

    expect($team)->toBeInstanceOf(Team::class);

    $team->members()->attach($member, ['role' => TeamRole::Member->value]);

    $response = $this
        ->actingAs($member)
        ->delete(route('users.bulk-destroy', ['current_team' => $team]), [
            'user_ids' => [$targetUser->id],
        ]);

    $response->assertForbidden();

    $this->assertDatabaseHas('users', ['id' => $targetUser->id]);
});
