export type TableFilters = {
    search?: string;
    sort?: string;
    direction?: 'asc' | 'desc';
    per_page?: number;
    page?: number;
};

type FlatParams = Record<string, string | number | undefined>;

export function toApiFilters(filters: TableFilters): FlatParams {
    const params: FlatParams = {};

    if (filters.search) {
        params['filter[search]'] = filters.search;
    }

    if (filters.sort) {
        params['sort'] =
            filters.direction === 'desc' ? `-${filters.sort}` : filters.sort;
    }

    if (filters.per_page) {
        params['page[size]'] = filters.per_page;
    }

    if (filters.page) {
        params['page[number]'] = filters.page;
    }

    return params;
}
