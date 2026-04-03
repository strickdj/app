<script setup lang="ts">
import { Head } from '@inertiajs/vue3';

const { status } = defineProps<{
    status: number;
}>();

const titleByStatus: Record<number, string> = {
    403: 'Forbidden',
    404: 'Page not found',
    500: 'Server error',
    503: 'Service unavailable',
};

const messageByStatus: Record<number, string> = {
    403: 'You are not authorized to access this page.',
    404: 'Sorry, we could not find the page you are looking for.',
    500: 'Something went wrong on our side.',
    503: 'The service is temporarily unavailable.',
};
</script>

<template>
    <Head title="Error"> </Head>
    <main
        class="grid min-h-full place-items-center bg-white px-6 py-24 sm:py-32 lg:px-8 dark:bg-gray-900"
    >
        <div class="text-center">
            <p
                class="text-base font-semibold text-indigo-600 dark:text-indigo-400"
            >
                {{ status }}
            </p>
            <h1
                class="mt-4 text-5xl font-semibold tracking-tight text-balance text-gray-900 sm:text-7xl dark:text-white"
            >
                {{ titleByStatus[status] ?? 'Unexpected error' }}
            </h1>
            <p
                class="mt-6 text-lg font-medium text-pretty text-gray-500 sm:text-xl/8 dark:text-gray-400"
            >
                {{
                    messageByStatus[status] ??
                    'An unexpected error occurred while loading this page.'
                }}
            </p>
            <div class="mt-10 flex items-center justify-center gap-x-6">
                <a
                    href="/"
                    class="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-xs hover:bg-indigo-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:bg-indigo-500 dark:hover:bg-indigo-400 dark:focus-visible:outline-indigo-500"
                    >Go back home</a
                >
                <a
                    href="/contact"
                    class="text-sm font-semibold text-gray-900 dark:text-white"
                    >Contact support <span aria-hidden="true">&rarr;</span></a
                >
            </div>
        </div>
    </main>
</template>
