export type DataTableRow = Record<string, unknown>;

export type DataTableColumnKey<TRow extends DataTableRow> = Extract<
    keyof TRow,
    string
>;

export type DataTableColumn<
    TRow extends DataTableRow = DataTableRow,
    TKey extends DataTableColumnKey<TRow> = DataTableColumnKey<TRow>,
> = {
    key: TKey;
    label?: string;
    sortable?: boolean;
    formatter?: {
        bivarianceHack(
            value: TRow[TKey],
            row: TRow,
            column: DataTableColumn<TRow, TKey>,
        ): string;
    }['bivarianceHack'];
};

export type DataTableColumns<TRow extends DataTableRow = DataTableRow> =
    Array<
        {
            [TKey in DataTableColumnKey<TRow>]: DataTableColumn<TRow, TKey>;
        }[DataTableColumnKey<TRow>]
    >;

export const defineDataTableColumns = <TRow extends DataTableRow>() => {
    return <
        const TColumns extends Array<DataTableColumns<TRow>[number]>,
    >(
        columns: TColumns,
    ): TColumns => {
        return columns;
    };
};
