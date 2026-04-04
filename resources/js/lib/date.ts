import { format, intlFormat, isValid, parseISO, toDate } from 'date-fns';

export const isDateColumn = (column: string): boolean => {
    return /^date$|_at$|_date$|_on$|date$/i.test(column);
};

export const parseDateValue = (value: unknown): Date | null => {
    if (value instanceof Date || typeof value === 'number') {
        const parsedDate = toDate(value);

        return isValid(parsedDate) ? parsedDate : null;
    }

    if (typeof value === 'string') {
        const parsedDate = parseISO(value);

        return isValid(parsedDate) ? parsedDate : null;
    }

    return null;
};

export const formatLocalizedDate = (
    date: Date,
    dateLocale?: string | string[],
    dateFormatOptions?: Intl.DateTimeFormatOptions,
): string => {
    if (dateLocale && dateFormatOptions) {
        return intlFormat(date, dateFormatOptions, { locale: dateLocale });
    }

    if (dateLocale) {
        return intlFormat(date, { locale: dateLocale });
    }

    if (dateFormatOptions) {
        return intlFormat(date, dateFormatOptions);
    }

    return intlFormat(date);
};

export const formatDateValue = (
    value: unknown,
    column?: string,
): string | null => {
    const parsedDate = parseDateValue(value);

    if (!parsedDate) {
        return null;
    }

    if (!(value instanceof Date) && (!column || !isDateColumn(column))) {
        return null;
    }

    return formatLocalizedDate(parsedDate);
};

export const formatDateTime = (
    date: Date,
    formatString = 'yyyy-MM-dd HH:mm:ss',
): string => {
    return format(date, formatString);
};
