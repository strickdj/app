<script setup lang="ts" generic="TRow extends DataTableRow">
import { FlexRender, getCoreRowModel, useVueTable } from '@tanstack/vue-table';
import type {
    CellContext,
    ColumnDef,
    HeaderContext,
    RowSelectionState,
    Updater,
} from '@tanstack/vue-table';
import { ArrowDown, ArrowUp, ArrowUpDown } from 'lucide-vue-next';
import { computed, h, ref, useSlots, watch } from 'vue';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
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
import type {
    DataTableBulkActionsSlotProps,
    DataTableColumn,
    DataTableColumnKey,
    DataTableColumns,
    DataTableRow,
} from '@/types';

type PaginatedItems = {
    data?: TRow[] | null;
    total?: number;
    current_page?: number;
    last_page?: number;
    per_page?: number;
};

type BaseProps = {
    items?: TRow[] | PaginatedItems;
    columns?: DataTableColumns<DataTableRow>;
    filters?: TableFilters;
    searchable?: boolean;
};

type SelectionProps =
    | { selectable: true; rowSelection?: RowSelectionState }
    | { selectable?: false; rowSelection?: never };

const props = withDefaults(defineProps<BaseProps & SelectionProps>(), {
    items: () => [],
    columns: () => [],
    filters: () => ({}),
    searchable: false,
    selectable: false,
});

const emit = defineEmits<{
    'update:filters': [filters: TableFilters];
    'update:rowSelection': [rowSelection: RowSelectionState];
    'update:selectedRowIds': [rowIds: string[]];
}>();

defineSlots<{
    'bulk-actions'?: (props: DataTableBulkActionsSlotProps) => unknown;
}>();

const slots = useSlots();

const rows = computed<TRow[]>(() => {
    if (Array.isArray(props.items)) {
        return props.items;
    }

    if (Array.isArray(props.items?.data)) {
        return props.items.data;
    }

    return [];
});

const inferredColumns = computed<DataTableColumns<TRow>>(() => {
    return Object.keys(rows.value[0] ?? {}).map((key) => ({
        key: key as DataTableColumnKey<TRow>,
    })) as DataTableColumns<TRow>;
});

const columns = computed<DataTableColumns<TRow>>(() => {
    if (props.columns.length > 0) {
        return props.columns as DataTableColumns<TRow>;
    }

    return inferredColumns.value;
});

const displayColumns = computed<DataTableColumns<TRow>>(() => {
    if (columns.value.length > 0) {
        return columns.value;
    }

    return [
        { key: 'items' as DataTableColumnKey<TRow> },
    ] as DataTableColumns<TRow>;
});

const renderedColumnCount = computed<number>(() => {
    return displayColumns.value.length + (props.selectable ? 1 : 0);
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

const formatCellValue = <TKey extends DataTableColumnKey<TRow>>(
    value: TRow[TKey],
    column: DataTableColumn<TRow, TKey>,
    row: TRow,
): unknown => {
    if (value === null || value === undefined || value === '') {
        return '—';
    }

    if (column.formatter) {
        return column.formatter(value, row, column);
    }

    return value;
};

const rowKey = (row: TRow, index: number): string | number => {
    const candidate = row.id;

    if (typeof candidate === 'string' || typeof candidate === 'number') {
        return candidate;
    }

    return index;
};

const localRowSelection = ref<RowSelectionState>({});

const isControlledRowSelection = computed<boolean>(() => {
    return props.selectable && props.rowSelection !== undefined;
});

const currentRowSelection = computed<RowSelectionState>(() => {
    if (!props.selectable) {
        return {};
    }

    return props.rowSelection ?? localRowSelection.value;
});

const hasDifferentSelection = (
    first: RowSelectionState,
    second: RowSelectionState,
): boolean => {
    const firstKeys = Object.keys(first);
    const secondKeys = Object.keys(second);

    if (firstKeys.length !== secondKeys.length) {
        return true;
    }

    return firstKeys.some((key) => first[key] !== second[key]);
};

const applyRowSelection = (selection: RowSelectionState): void => {
    if (!isControlledRowSelection.value) {
        localRowSelection.value = selection;
    }

    emit('update:rowSelection', selection);

    const selectedRowIds = Object.entries(selection)
        .filter(([, isSelected]) => Boolean(isSelected))
        .map(([id]) => id);

    emit('update:selectedRowIds', selectedRowIds);
};

const selectedRowIds = computed<string[]>(() => {
    return Object.entries(currentRowSelection.value)
        .filter(([, isSelected]) => Boolean(isSelected))
        .map(([id]) => id);
});

const selectedCount = computed<number>(() => {
    return selectedRowIds.value.length;
});

const clearSelection = (): void => {
    if (!props.selectable) {
        return;
    }

    applyRowSelection({});
};

const hasBulkActionsSlot = computed<boolean>(() => {
    return props.selectable && slots['bulk-actions'] !== undefined;
});

const hasToolbar = computed<boolean>(() => {
    return props.searchable || hasBulkActionsSlot.value;
});

watch(
    rows,
    (currentRows) => {
        if (!props.selectable || isControlledRowSelection.value) {
            return;
        }

        const visibleRowIds = new Set(
            currentRows.map((row, index) => String(rowKey(row, index))),
        );

        const nextSelection = Object.fromEntries(
            Object.entries(localRowSelection.value).filter(
                ([id, isSelected]) => Boolean(isSelected) && visibleRowIds.has(id),
            ),
        );

        if (hasDifferentSelection(localRowSelection.value, nextSelection)) {
            applyRowSelection(nextSelection);
        }
    },
    { immediate: true },
);

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

const isColumnSortable = <TKey extends DataTableColumnKey<TRow>>(
    column: DataTableColumn<TRow, TKey>,
): boolean => {
    return column.sortable === true;
};

const createColumnDefinition = <TKey extends DataTableColumnKey<TRow>>(
    column: DataTableColumn<TRow, TKey>,
): ColumnDef<TRow> => {
    return {
        id: column.key,
        accessorFn: (row: TRow): TRow[TKey] => row[column.key],
        enableSorting: isColumnSortable(column),
        header: column.label ?? formatColumnLabel(column.key),
        cell: ({ getValue, row }: CellContext<TRow, TRow[TKey]>) =>
            formatCellValue(getValue() as TRow[TKey], column, row.original),
    };
};

const columnDefinitions = computed<ColumnDef<TRow>[]>(() => {
    const baseColumns = displayColumns.value.map((column) => ({
        ...createColumnDefinition(column),
    }));

    if (!props.selectable) {
        return baseColumns;
    }

    return [
        {
            id: '__select',
            enableSorting: false,
            header: ({ table }: HeaderContext<TRow, unknown>) =>
                h(Checkbox, {
                    modelValue: table.getIsAllPageRowsSelected()
                        ? true
                        : table.getIsSomePageRowsSelected()
                          ? 'indeterminate'
                          : false,
                    'aria-label': 'Select all rows',
                    'onUpdate:modelValue': (
                        value: boolean | 'indeterminate',
                    ) => {
                        table.toggleAllPageRowsSelected(Boolean(value));
                    },
                }),
            cell: ({ row }: CellContext<TRow, unknown>) =>
                h(Checkbox, {
                    modelValue: row.getIsSelected(),
                    'aria-label': 'Select row',
                    'onUpdate:modelValue': (
                        value: boolean | 'indeterminate',
                    ) => {
                        row.toggleSelected(Boolean(value));
                    },
                }),
        },
        ...baseColumns,
    ];
});

const table = useVueTable<TRow>({
    data: rows,
    get columns() {
        return columnDefinitions.value;
    },
    getRowId: (originalRow, index) => String(rowKey(originalRow, index)),
    getCoreRowModel: getCoreRowModel(),
    manualSorting: true,
    enableRowSelection: () => props.selectable,
    manualPagination: true,
    onRowSelectionChange: (updater: Updater<RowSelectionState>) => {
        const nextSelection =
            typeof updater === 'function'
                ? updater(currentRowSelection.value)
                : updater;

        applyRowSelection(nextSelection);
    },
    state: {
        get rowSelection() {
            return currentRowSelection.value;
        },
    },
});

const headerGroups = ref(table.getHeaderGroups());
const tableRows = ref(table.getRowModel().rows);

watch(columnDefinitions, () => {
    headerGroups.value = table.getHeaderGroups();
});

watch([rows, columnDefinitions, currentRowSelection], () => {
    tableRows.value = table.getRowModel().rows;
});

const getSortDirection = (
    direction?: TableFilters['direction'],
): TableFilters['direction'] => {
    if (direction === 'asc') {
        return 'desc';
    }

    if (direction === 'desc') {
        return undefined;
    }

    return 'asc';
};

const onSortColumn = (column: string): void => {
    const sortableColumn = displayColumns.value.find(
        (displayColumn) => displayColumn.key === column,
    );

    if (!sortableColumn || !isColumnSortable(sortableColumn)) {
        return;
    }

    const isSameColumn = props.filters?.sort === column;
    const newDirection = isSameColumn
        ? getSortDirection(props.filters?.direction)
        : 'asc';

    emit('update:filters', {
        ...props.filters,
        sort: newDirection ? column : undefined,
        direction: newDirection,
        page: 1,
    });
};
</script>

<template>
    <div class="flex flex-col gap-3">
        <div
            v-if="hasToolbar"
            class="flex flex-wrap items-center justify-between gap-2"
        >
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

            <slot
                v-if="hasBulkActionsSlot"
                name="bulk-actions"
                :selected-row-ids="selectedRowIds"
                :selected-count="selectedCount"
                :clear-selection="clearSelection"
            />
        </div>

        <Table>
            <TableCaption>
                Showing {{ rows.length }} of {{ totalItems }} items.
            </TableCaption>
            <TableHeader>
                <TableRow
                    v-for="headerGroup in headerGroups"
                    :key="headerGroup.id"
                >
                    <TableHead
                        v-for="header in headerGroup.headers"
                        :key="header.id"
                        :class="
                            !header.isPlaceholder && header.column.getCanSort()
                                ? 'cursor-pointer select-none'
                                : ''
                        "
                        @click="
                            !header.isPlaceholder &&
                            onSortColumn(header.column.id)
                        "
                    >
                        <span
                            v-if="!header.isPlaceholder"
                            class="flex items-center gap-1"
                        >
                            <FlexRender
                                :render="header.column.columnDef.header"
                                :props="header.getContext()"
                            />
                            <template v-if="header.column.getCanSort()">
                                <ArrowUp
                                    v-if="
                                        filters?.sort === header.column.id &&
                                        filters?.direction === 'asc'
                                    "
                                    class="size-3.5 shrink-0"
                                />
                                <ArrowDown
                                    v-else-if="
                                        filters?.sort === header.column.id &&
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
                <TableRow v-if="tableRows.length === 0">
                    <TableCell
                        :colspan="renderedColumnCount"
                        class="text-center text-muted-foreground"
                    >
                        No items found.
                    </TableCell>
                </TableRow>
                <TableRow
                    v-for="row in tableRows"
                    v-else
                    :key="row.id"
                    :data-state="row.getIsSelected() ? 'selected' : undefined"
                >
                    <TableCell
                        v-for="cell in row.getVisibleCells()"
                        :key="cell.id"
                        class="align-top"
                    >
                        <FlexRender
                            :render="cell.column.columnDef.cell"
                            :props="cell.getContext()"
                        />
                    </TableCell>
                </TableRow>
            </TableBody>
            <TableFooter>
                <TableRow>
                    <TableCell v-if="renderedColumnCount === 1">
                        Total: {{ totalItems }}
                    </TableCell>
                    <TableCell v-else :colspan="renderedColumnCount - 1">
                        Total
                    </TableCell>
                    <TableCell
                        v-if="renderedColumnCount > 1"
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
