<?php

use App\Http\Controllers\Teams\TeamInvitationController;
use App\Http\Middleware\EnsureTeamMembership;
use App\Models\User;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;
use Laravel\Fortify\Features;

Route::inertia('/', 'Welcome', [
    'canRegister' => Features::enabled(Features::registration()),
])->name('home');

Route::prefix('{current_team}')
    ->middleware(['auth', 'verified', EnsureTeamMembership::class])
    ->group(function (): void {
        Route::inertia('dashboard', 'Dashboard')->name('dashboard');
        Route::inertia('users', 'Users')->name('dashboard');
        Route::get('users', function () {
            $users = User::with(['teams'])
//                ->withPivot('role')
                ->paginate();

            return Inertia::render('Users', [
                'users' => $users,
            ]);
        })->name('users');

    });

Route::middleware(['auth'])->group(function (): void {
    Route::get('invitations/{invitation}/accept', [TeamInvitationController::class, 'accept'])->name('invitations.accept');
});

require __DIR__.'/settings.php';
