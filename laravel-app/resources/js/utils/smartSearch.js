export function normalizeSearchText(value) {
    return String(value ?? '')
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '');
}

export function splitQuery(query) {
    return normalizeSearchText(query)
        .split(/\s+/)
        .map((t) => t.trim())
        .filter(Boolean);
}

export function matchesQuery(haystack, query) {
    const tokens = splitQuery(query);
    if (tokens.length === 0) return true;
    const text = normalizeSearchText(haystack);
    return tokens.every((t) => text.includes(t));
}

export function filterByQuery(items, query, getValues) {
    const tokens = splitQuery(query);
    if (tokens.length === 0) return items;

    return (items ?? []).filter((item) => {
        const values = getValues(item) ?? [];
        const haystack = values.map((v) => (v === null || v === undefined ? '' : String(v))).join(' ');
        const text = normalizeSearchText(haystack);
        return tokens.every((t) => text.includes(t));
    });
}
