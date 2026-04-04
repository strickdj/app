<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
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
            ->paginate($request->integer('page.size', 15))
            ->withQueryString();

        $rawSort = (string) $request->input('sort', '');

        return Inertia::render('Users', [
            'users' => $users,
            'filters' => [
                'search' => (string) $request->input('filter.search', ''),
                'sort' => ltrim($rawSort, '-'),
                'direction' => str_starts_with($rawSort, '-') ? 'desc' : 'asc',
                'per_page' => $request->integer('page.size', 15),
            ],
        ]);
    }
}
