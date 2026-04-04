<script setup lang="ts">
import { ArrowDown, ArrowUp, ArrowUpDown } from 'lucide-vue-next';
import { computed, ref, watch } from 'vue';
import { Input } from '@/components/ui/input';
import {
    Table,
    TableBody,
    TableCaption,
    TableCell,
    TableFooter,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import type { TableFilters } from '@/lib/toApiFilters';

type DataTableRow = Record<string, unknown>;
type PaginatedItems = {
    data?: DataTableRow[] | null;
    total?: number;
};

const props = withDefaults(
    defineProps<{
        items?: DataTableRow[] | PaginatedItems;
        columns?: string[];
        filters?: TableFilters;
        searchable?: boolean;
        sortable?: boolean | string[];
    }>(),
    {
        items: () => [],
        columns: () => [],
        filters: () => ({}),
        searchable: false,
        sortable: false,
    },
);

const emit = defineEmits<{
    'update:filters': [filters: TableFilters];
}>();

const rows = computed<DataTableRow[]>(() => {
    if (Array.isArray(props.items)) {
        return props.items;
    }

    if (Array.isArray(props.items?.data)) {
        return props.items.data;
    }

    return [];
});

const inferredColumns = computed<string[]>(() => {
    return Object.keys(rows.value[0] ?? {});
});

const columns = computed<string[]>(() => {
    if (props.columns.length > 0) {
        return props.columns;
    }

    return inferredColumns.value;
});

const displayColumns = computed<string[]>(() => {
    return columns.value.length > 0 ? columns.value : ['items'];
});

const totalItems = computed<number>(() => {
    if (Array.isArray(props.items)) {
        return props.items.length;
    }

    if (typeof props.items?.total === 'number') {
        return props.items.total;
    }

    return rows.value.length;
});

const formatColumnLabel = (column: string): string => {
    return column
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (character) => character.toUpperCase());
};

const formatObjectValue = (value: Record<string, unknown>): string => {
    for (const key of ['name', 'label', 'title', 'slug', 'email', 'id']) {
        const candidate = value[key];

        if (typeof candidate === 'string' || typeof candidate === 'number') {
            return String(candidate);
        }
    }

    return JSON.stringify(value) ?? '—';
};

const formatCellValue = (value: unknown): string => {
    if (value === null || value === undefined || value === '') {
        return '—';
    }

    if (Array.isArray(value)) {
        return value.length > 0
            ? value
                  .map((item) => {
                      if (item && typeof item === 'object') {
                          return formatObjectValue(item as Record<string, unknown>);
                      }

                      return String(item);
                  })
                  .join(', ')
            : '—';
    }

    if (typeof value === 'object') {
        return formatObjectValue(value as Record<string, unknown>);
    }

    return String(value);
};

const rowKey = (row: DataTableRow, index: number): string | number => {
    const candidate = row.id;

    if (typeof candidate === 'string' || typeof candidate === 'number') {
        return candidate;
    }

    return index;
};

const searchInput = ref(props.filters?.search ?? '');

watch(
    () => props.filters?.search,
    (value) => {
        searchInput.value = value ?? '';
    },
);

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

const onSearchInput = (event: Event) => {
    const value = (event.target as HTMLInputElement).value;

    searchInput.value = value;

    if (debounceTimer) {
        clearTimeout(debounceTimer);
    }

    debounceTimer = setTimeout(() => {
        emit('update:filters', { ...props.filters, search: value, page: 1 });
    }, 300);
};

const isColumnSortable = (column: string): boolean => {
    if (props.sortable === true) {
        return true;
    }

    if (Array.isArray(props.sortable)) {
        return props.sortable.includes(column);
    }

    return false;
};

const onSortColumn = (column: string) => {
    if (!isColumnSortable(column)) {
        return;
    }

    const isSameColumn = props.filters?.sort === column;
    const newDirection =
        isSameColumn && props.filters?.direction === 'asc' ? 'desc' : 'asc';

    emit('update:filters', {
        ...props.filters,
        sort: column,
        direction: newDirection,
        page: 1,
    });
};
</script>

<template>
    <div class="flex flex-col gap-3">
        <Input
            v-if="searchable"
            :value="searchInput"
            placeholder="Search..."
            class="max-w-sm"
            @input="onSearchInput"
        />

        <Table>
            <TableCaption>
                Showing {{ rows.length }} of {{ totalItems }} items.
            </TableCaption>
            <TableHeader>
                <TableRow>
                    <TableHead
                        v-for="column in displayColumns"
                        :key="column"
                        :class="isColumnSortable(column) ? 'cursor-pointer select-none' : ''"
                        @click="onSortColumn(column)"
                    >
                        <span class="flex items-center gap-1">
                            {{ formatColumnLabel(column) }}
                            <template v-if="isColumnSortable(column)">
                                <ArrowUp
                                    v-if="filters?.sort === column && filters?.direction === 'asc'"
                                    class="size-3.5 shrink-0"
                                />
                                <ArrowDown
                                    v-else-if="filters?.sort === column && filters?.direction === 'desc'"
                                    class="size-3.5 shrink-0"
                                />
                                <ArrowUpDown
                                    v-else
                                    class="size-3.5 shrink-0 opacity-40"
                                />
                            </template>
                        </span>
                    </TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                <TableRow v-if="rows.length === 0">
                    <TableCell :colspan="displayColumns.length" class="text-center text-muted-foreground">
                        No items found.
                    </TableCell>
                </TableRow>
                <TableRow v-for="(row, index) in rows" v-else :key="rowKey(row, index)">
                    <TableCell v-for="column in columns" :key="`${rowKey(row, index)}-${column}`" class="align-top">
                        {{ formatCellValue(row[column]) }}
                    </TableCell>
                </TableRow>
            </TableBody>
            <TableFooter>
                <TableRow>
                    <TableCell v-if="displayColumns.length === 1">
                        Total: {{ totalItems }}
                    </TableCell>
                    <TableCell v-else :colspan="displayColumns.length - 1">
                        Total
                    </TableCell>
                    <TableCell v-if="displayColumns.length > 1" class="text-right">
                        {{ totalItems }}
                    </TableCell>
                </TableRow>
            </TableFooter>
        </Table>
    </div>
</template>
