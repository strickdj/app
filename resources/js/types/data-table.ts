export type DataTableRow = Record<string, unknown>;

export type DataTableColumn = {
    key: string;
    label?: string;
    sortable?: boolean;
    formatter?: (
        value: unknown,
        row: DataTableRow,
        column: DataTableColumn,
    ) => string;
};
