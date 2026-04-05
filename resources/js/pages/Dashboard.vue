<script setup lang="ts">
import { Head } from '@inertiajs/vue3';
import AppLayout from '@/layouts/AppLayout.vue';
import { dashboard } from '@/routes';
import type { Team } from '@/types';

defineOptions({
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
    <Head title="Dashboard" />

    <div class="flex flex-col gap-4 overflow-x-auto rounded-xl p-4"></div>
</template>
