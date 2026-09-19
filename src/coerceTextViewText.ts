import { isValidElement } from 'react';

/**
 * Coerces a dynamic text expression into the canonical `text` prop surface.
 *
 * This is intentionally strict: text expressions may vanish (`null`, booleans)
 * or produce textual primitives, but they may not pass React nodes or objects
 * through the direct-text path.
 */
export function coerceTextViewText(value: unknown): string {
  if (value == null || value === false || value === true) return '';
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'bigint') return String(value);

  if (Array.isArray(value) || isValidElement(value)) {
    throw new Error(
      'RNTextEngine: TextView text expressions must resolve to text-like values. Forward ReactNode content through children instead of the direct `text` path.'
    );
  }

  throw new Error('RNTextEngine: TextView text expressions must resolve to text-like values.');
}
