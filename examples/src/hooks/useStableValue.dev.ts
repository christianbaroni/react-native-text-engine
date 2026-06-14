import { useMemo } from 'react';

/**
 * Dev-only wrapper that preserves stable-value semantics across renders while
 * resetting on Fast Refresh module re-evaluation.
 */
export function useStableValue<T>(init: () => T): T {
  // eslint-disable-next-line react-hooks/exhaustive-deps -- allows fast refresh rebuild in dev mode
  return useMemo(() => init(), []);
}
