<?php

namespace App\Http\Controllers;

use App\Http\Requests\Users\BulkDestroyUsersRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;
use Spatie\QueryBuilder\AllowedFilter;
use Spatie\QueryBuilder\QueryBuilder;

class UserController extends Controller
{
    /**
     * Display a paginated, filterable list of users.
     */
    public function index(Request $request): Response
    {
        $user = $request->user();
        $currentTeam = $user?->currentTeam;
        $perPage = $request->integer('page.size', 10);
        $currentPage = $request->integer('page.number', 1);

        $users = QueryBuilder::for(User::class)
            ->allowedFilters(
                AllowedFilter::callback('search', function (Builder $query, mixed $value): void {
                    $searchTerm = trim((string) $value);

                    if ($searchTerm === '') {
                        return;
                    }

                    $query->where(function (Builder $nestedQuery) use ($searchTerm): void {
                        $nestedQuery
                            ->where('name', 'like', "%{$searchTerm}%")
                            ->orWhere('email', 'like', "%{$searchTerm}%");
                    });
                }),
            )
            ->allowedSorts('name', 'email', 'created_at')
            ->with('teams')
            ->paginate($perPage, page: $currentPage)
            ->withQueryString();

        $rawSort = (string) $request->input('sort', '');

        return Inertia::render('Users', [
            'users' => $users,
            'canBulkDeleteUsers' => $currentTeam !== null
                ? $user->hasTeamPermission($currentTeam, 'member:remove')
                : false,
            'filters' => [
                'search' => (string) $request->input('filter.search', ''),
                'sort' => ltrim($rawSort, '-'),
                'direction' => str_starts_with($rawSort, '-') ? 'desc' : 'asc',
                'per_page' => $perPage,
                'page' => $currentPage,
            ],
        ]);
    }

    /**
     * Delete the selected users.
     */
    public function bulkDestroy(BulkDestroyUsersRequest $request): RedirectResponse
    {
        /** @var array<int, int> $userIds */
        $userIds = $request->validated('user_ids');

        DB::transaction(function () use ($userIds): void {
            User::query()
                ->whereKey($userIds)
                ->get()
                ->each(function (User $user): void {
                    $user->delete();
                });
        });

        return back();
    }
}
