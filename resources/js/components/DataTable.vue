<script setup lang="ts">
import { ArrowDown, ArrowUp, ArrowUpDown } from 'lucide-vue-next';
import { computed, ref, watch } from 'vue';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
    Pagination,
    PaginationContent,
    PaginationEllipsis,
    PaginationItem,
    PaginationNext,
    PaginationPrevious,
} from '@/components/ui/pagination';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
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
    current_page?: number;
    last_page?: number;
    per_page?: number;
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

const paginatedItems = computed<PaginatedItems | null>(() => {
    return Array.isArray(props.items) ? null : props.items;
});

const isPaginated = computed<boolean>(() => {
    return typeof paginatedItems.value?.last_page === 'number';
});

const currentPage = computed<number>(() => {
    if (typeof paginatedItems.value?.current_page === 'number') {
        return paginatedItems.value.current_page;
    }

    return 1;
});

const activePage = ref(currentPage.value);

const lastPage = computed<number>(() => {
    if (typeof paginatedItems.value?.last_page === 'number') {
        return paginatedItems.value.last_page;
    }

    return 1;
});

const rowsPerPage = computed<number>(() => {
    if (typeof props.filters?.per_page === 'number') {
        return props.filters.per_page;
    }

    if (typeof paginatedItems.value?.per_page === 'number') {
        return paginatedItems.value.per_page;
    }

    return 10;
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
                          return formatObjectValue(
                              item as Record<string, unknown>,
                          );
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

watch(
    currentPage,
    (value) => {
        activePage.value = value;
    },
    { immediate: true },
);

const onSearchClick = (): void => {
    emit('update:filters', {
        ...props.filters,
        search: searchInput.value,
        page: 1,
    });
};

const onClearSearch = (): void => {
    searchInput.value = '';

    emit('update:filters', {
        ...props.filters,
        search: '',
        page: 1,
    });
};

const onRowsPerPageChange = (value: unknown): void => {
    if (value === null) {
        return;
    }

    const parsedValue = Number(value);

    if (Number.isNaN(parsedValue)) {
        return;
    }

    emit('update:filters', {
        ...props.filters,
        per_page: parsedValue,
        page: 1,
    });
};

const goToPage = (page: number): void => {
    if (page < 1 || page > lastPage.value || page === activePage.value) {
        return;
    }

    activePage.value = page;

    emit('update:filters', {
        ...props.filters,
        page,
    });
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
        <div v-if="searchable" class="flex max-w-md items-center gap-2">
            <Input
                v-model="searchInput"
                placeholder="Search..."
                @keydown.enter.prevent="onSearchClick"
            />
            <Button type="button" @click="onSearchClick"> Search </Button>
            <Button
                type="button"
                variant="outline"
                :disabled="searchInput === '' && (filters?.search ?? '') === ''"
                @click="onClearSearch"
            >
                Clear
            </Button>
        </div>

        <Table>
            <TableCaption>
                Showing {{ rows.length }} of {{ totalItems }} items.
            </TableCaption>
            <TableHeader>
                <TableRow>
                    <TableHead
                        v-for="column in displayColumns"
                        :key="column"
                        :class="
                            isColumnSortable(column)
                                ? 'cursor-pointer select-none'
                                : ''
                        "
                        @click="onSortColumn(column)"
                    >
                        <span class="flex items-center gap-1">
                            {{ formatColumnLabel(column) }}
                            <template v-if="isColumnSortable(column)">
                                <ArrowUp
                                    v-if="
                                        filters?.sort === column &&
                                        filters?.direction === 'asc'
                                    "
                                    class="size-3.5 shrink-0"
                                />
                                <ArrowDown
                                    v-else-if="
                                        filters?.sort === column &&
                                        filters?.direction === 'desc'
                                    "
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
                    <TableCell
                        :colspan="displayColumns.length"
                        class="text-center text-muted-foreground"
                    >
                        No items found.
                    </TableCell>
                </TableRow>
                <TableRow
                    v-for="(row, index) in rows"
                    v-else
                    :key="rowKey(row, index)"
                >
                    <TableCell
                        v-for="column in columns"
                        :key="`${rowKey(row, index)}-${column}`"
                        class="align-top"
                    >
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
                    <TableCell
                        v-if="displayColumns.length > 1"
                        class="text-right"
                    >
                        {{ totalItems }}
                    </TableCell>
                </TableRow>
            </TableFooter>
        </Table>

        <div
            v-if="isPaginated"
            class="flex items-center justify-between gap-3 overflow-x-auto"
        >
            <div class="flex items-center gap-2">
                <span class="text-sm text-muted-foreground">Rows per page</span>
                <Select
                    :model-value="String(rowsPerPage)"
                    @update:model-value="onRowsPerPageChange"
                >
                    <SelectTrigger class="w-24">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="10">10</SelectItem>
                        <SelectItem value="20">20</SelectItem>
                        <SelectItem value="50">50</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            <Pagination
                class="mx-0 w-auto shrink-0 justify-end"
                :total="lastPage"
                :items-per-page="1"
                :sibling-count="1"
                show-edges
                :page="activePage"
                @update:page="goToPage"
            >
                <PaginationContent v-slot="{ items }">
                    <PaginationPrevious :disabled="activePage <= 1" />

                    <template
                        v-for="(item, index) in items"
                        :key="`${item.type}-${index}`"
                    >
                        <PaginationEllipsis v-if="item.type === 'ellipsis'" />

                        <PaginationItem
                            v-else
                            :value="item.value"
                            :is-active="item.value === activePage"
                            :class="
                                item.value === activePage
                                    ? 'border-primary bg-primary text-primary-foreground hover:bg-primary/90 hover:text-primary-foreground dark:bg-primary dark:text-primary-foreground dark:hover:bg-primary/90'
                                    : undefined
                            "
                            :aria-current="
                                item.value === activePage ? 'page' : undefined
                            "
                        >
                            {{ item.value }}
                        </PaginationItem>
                    </template>

                    <PaginationNext :disabled="activePage >= lastPage" />
                </PaginationContent>
            </Pagination>
        </div>
    </div>
</template>
