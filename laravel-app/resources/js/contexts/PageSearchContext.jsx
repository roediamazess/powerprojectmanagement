import { createContext, useMemo } from 'react';

export const PageSearchContext = createContext({
    query: '',
    setQuery: () => {},
    clear: () => {},
});

export function PageSearchProvider({ children, query, setQuery }) {
    const value = useMemo(() => {
        return {
            query: query ?? '',
            setQuery: setQuery ?? (() => {}),
            clear: () => (setQuery ? setQuery('') : undefined),
        };
    }, [query, setQuery]);

    return <PageSearchContext.Provider value={value}>{children}</PageSearchContext.Provider>;
}
