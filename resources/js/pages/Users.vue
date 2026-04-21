<script setup lang="ts">
import { Head, router, useForm } from '@inertiajs/vue3';
import type { RowSelectionState } from '@tanstack/vue-table';
import { ref } from 'vue';
import { index } from '@/actions/App/Http/Controllers/UserController';
import DataTable from '@/components/DataTable.vue';
import InputError from '@/components/InputError.vue';
import { Button } from '@/components/ui/button';
import AppLayout from '@/layouts/AppLayout.vue';
import { formatDateTime, parseDateValue } from '@/lib/date';
import { toApiFilters } from '@/lib/toApiFilters';
import type { TableFilters } from '@/lib/toApiFilters';
import { dashboard } from '@/routes';
import type { DataTableColumns, DataTableRow, Team, User } from '@/types';
import { defineDataTableColumns } from '@/types';

type PaginatedItems<T> = {
    data: T[];
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
};

type Props = {
    canBulkDeleteUsers: boolean;
    currentTeam?: Team | null;
    users: PaginatedItems<UserTableRow>;
    filters: TableFilters;
};

type UserTableRow = Pick<User, 'id' | 'name' | 'email' | 'created_at'> & {
    teams: Team[];
};

const props = defineProps<Props>();
const rowSelection = ref<RowSelectionState>({});
const bulkDeleteForm = useForm<{ user_ids: number[] }>({
    user_ids: [],
});

const userTableColumns = defineDataTableColumns<UserTableRow>()([
    { key: 'id', hideable: false },
    { key: 'name', sortable: true },
    { key: 'email', sortable: true },
    {
        key: 'teams',
        defaultVisible: false,
        formatter: (value): string => value[0]?.name ?? '—',
    },
    {
        key: 'created_at',
        sortable: true,
        formatter: (value): string => {
            const date = parseDateValue(value);

            if (!date) {
                return value === null || value === undefined || value === ''
                    ? '—'
                    : String(value);
            }

            return formatDateTime(date);
        },
    },
]);

const dataTableColumns: DataTableColumns<DataTableRow> = userTableColumns;

const submitBulkDelete = (
    selectedRowIds: string[],
    clearSelection: () => void,
): void => {
    if (!props.currentTeam || selectedRowIds.length === 0) {
        return;
    }

    bulkDeleteForm.user_ids = selectedRowIds.map((id) => Number(id));

    bulkDeleteForm.delete(index(props.currentTeam.slug).url, {
        preserveState: true,
        preserveScroll: true,
        replace: true,
        onSuccess: () => {
            bulkDeleteForm.reset();
            bulkDeleteForm.clearErrors();
            clearSelection();
            rowSelection.value = {};

            // Ensure the paginated users payload is re-fetched after deletion.
            router.reload({
                only: ['users', 'filters', 'canBulkDeleteUsers'],
            });
        },
    });
};

const handleFiltersUpdate = (filters: TableFilters): void => {
    if (!props.currentTeam) {
        return;
    }

    router.get(index(props.currentTeam.slug).url, toApiFilters(filters), {
        preserveState: true,
        preserveScroll: true,
        replace: true,
    });
};

defineOptions({
    inheritAttrs: false,
    layout: (props: { currentTeam?: Team | null }) => [
        AppLayout,
        {
            breadcrumbs: [
                {
                    title: 'Dashboard',
                    href: props.currentTeam
                        ? dashboard(props.currentTeam.slug)
                        : '/',
                },
            ],
        },
    ],
});
</script>

<template>
    <Head title="Users" />

    <div class="flex flex-col gap-4 overflow-x-auto rounded-xl p-4">
        <DataTable
            :items="users"
            :columns="dataTableColumns"
            :filters="filters"
            :searchable="true"
            :selectable="true"
            @update:filters="handleFiltersUpdate"
        >
            <template
                #bulk-actions="{
                    selectedRowIds,
                    selectedCount,
                    clearSelection,
                }"
            >
                <div class="flex flex-col gap-1">
                    <div class="flex items-center gap-2">
                        <span class="text-sm text-muted-foreground">
                            {{ selectedCount }} selected
                        </span>

                        <Button
                            v-if="canBulkDeleteUsers"
                            type="button"
                            variant="destructive"
                            :disabled="
                                selectedCount === 0 || bulkDeleteForm.processing
                            "
                            @click="
                                submitBulkDelete(selectedRowIds, clearSelection)
                            "
                        >
                            Delete selected
                        </Button>

                        <Button
                            type="button"
                            variant="outline"
                            :disabled="
                                selectedCount === 0 || bulkDeleteForm.processing
                            "
                            @click="clearSelection"
                        >
                            Clear selection
                        </Button>
                    </div>

                    <InputError :message="bulkDeleteForm.errors.user_ids" />
                </div>
            </template>
        </DataTable>
    </div>
</template>
