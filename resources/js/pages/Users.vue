<script setup lang="ts">
import { Head, router } from '@inertiajs/vue3';
import { index } from '@/actions/App/Http/Controllers/UserController';
import DataTable from '@/components/DataTable.vue';
import AppLayout from '@/layouts/AppLayout.vue';
import { toApiFilters } from '@/lib/toApiFilters';
import type { TableFilters } from '@/lib/toApiFilters';
import { dashboard } from '@/routes';
import type { Team, User } from '@/types';

type PaginatedItems<T> = {
    data: T[];
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
};

type Props = {
    currentTeam?: Team | null;
    users: PaginatedItems<User>;
    filters: TableFilters;
};

const props = defineProps<Props>();

const userTableColumns = ['id', 'name', 'email', 'teams'];

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
            :columns="userTableColumns"
            :filters="filters"
            :searchable="true"
            :sortable="['name', 'email', 'created_at']"
            @update:filters="handleFiltersUpdate"
        />
    </div>
</template>
