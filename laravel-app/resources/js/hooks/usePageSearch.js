import { useContext } from 'react';
import { PageSearchContext } from '@/contexts/PageSearchContext';

export function usePageSearch() {
    return useContext(PageSearchContext);
}
