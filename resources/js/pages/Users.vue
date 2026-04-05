<script setup lang="ts">
import { Head, router, useRemember } from '@inertiajs/vue3';
import type { RowSelectionState } from '@tanstack/vue-table';
import { index } from '@/actions/App/Http/Controllers/UserController';
import DataTable from '@/components/DataTable.vue';
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
const rowSelection = useRemember<RowSelectionState>(
    {},
    `users.${props.currentTeam?.slug ?? 'default'}.row-selection`,
);

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
            v-model:rowSelection="rowSelection"
            :items="users"
            :columns="dataTableColumns"
            :filters="filters"
            :searchable="true"
            :selectable="true"
            @update:filters="handleFiltersUpdate"
        />
    </div>
</template>
