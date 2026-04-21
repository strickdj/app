<?php

namespace App\Http\Requests\Users;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class BulkDestroyUsersRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        $user = $this->user();
        $currentTeam = $user?->currentTeam;

        if ($user === null || $currentTeam === null) {
            return false;
        }

        return $user->hasTeamPermission($currentTeam, 'member:remove');
    }

    /**
     * Configure the validator instance.
     *
     * @return array<int, Closure(Validator): void>
     */
    public function after(): array
    {
        return [function (Validator $validator): void {
            $authenticatedUserId = $this->user()?->id;

            if ($authenticatedUserId === null) {
                return;
            }

            $selectedUserIds = collect($this->input('user_ids', []))
                ->map(fn (mixed $id): int => (int) $id)
                ->all();

            if (in_array($authenticatedUserId, $selectedUserIds, true)) {
                $validator->errors()->add('user_ids', 'You cannot delete your own account.');
            }
        }];
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'user_ids' => ['required', 'array', 'min:1'],
            'user_ids.*' => ['required', 'integer', 'distinct', 'exists:users,id'],
        ];
    }
}
