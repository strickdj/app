<script setup lang="ts">
import { Head } from '@inertiajs/vue3';
import DataTable from '@/components/DataTable.vue';
import AppLayout from '@/layouts/AppLayout.vue';
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
};

defineProps<Props>();

const userTableColumns = ['id', 'name', 'email', 'teams'];

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
        <DataTable :items="users" :columns="userTableColumns" />
    </div>
</template>
