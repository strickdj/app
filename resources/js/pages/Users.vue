<script setup lang="ts">
import { Head, router } from '@inertiajs/vue3';
import { index } from '@/actions/App/Http/Controllers/UserController';
import DataTable from '@/components/DataTable.vue';
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
    currentTeam?: Team | null;
    users: PaginatedItems<UserTableRow>;
    filters: TableFilters;
};

type UserTableRow = Pick<User, 'id' | 'name' | 'email' | 'created_at'> & {
    teams: Team[];
};

const props = defineProps<Props>();

const userTableColumns = defineDataTableColumns<UserTableRow>()([
    { key: 'id' },
    { key: 'name', sortable: true },
    { key: 'email', sortable: true },
    {
        key: 'teams',
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
            <template #bulk-actions="{ selectedCount, clearSelection }">
                <div class="flex items-center gap-2">
                    <span class="text-sm text-muted-foreground">
                        {{ selectedCount }} selected
                    </span>
                    <Button
                        type="button"
                        variant="outline"
                        :disabled="selectedCount === 0"
                        @click="clearSelection"
                    >
                        Clear selection
                    </Button>
                </div>
            </template>
        </DataTable>
    </div>
</template>
