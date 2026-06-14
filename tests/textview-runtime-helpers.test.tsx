import { Fragment, isValidElement, type ReactElement, type ReactNode } from 'react';
import { describe, expect, it } from 'vitest';
import { coerceTextViewText } from '../src/coerceTextViewText';
import { normalizeTextViewChildren } from '../src/normalizeTextViewChildren';

function MockTextView(_props: { children?: ReactNode; text?: string }) {
  return null;
}

function Marker(_props: { label?: string }) {
  return null;
}

describe('TextView runtime helpers', () => {
  it('coalesces contiguous primitive text from iterables into one nested TextView span', () => {
    const result = normalizeTextViewChildren(new Set<ReactNode>(['alpha', 2, ' beta']), MockTextView);

    const element = requireElement<{ children?: ReactNode; text?: string }>(result);
    if (element.type !== MockTextView) {
      throw new Error('Expected normalized children to resolve to MockTextView.');
    }
    expect(element.type).toBe(MockTextView);
    expect(element.props.text).toBe('alpha2 beta');
  });

  it('preserves elements while recursively lowering fragment and array text', () => {
    const result = normalizeTextViewChildren(
      [<Fragment key="prefix">alpha{' beta'}</Fragment>, <Marker key="marker" label="mid" />, [' gamma']],
      MockTextView
    );

    expect(Array.isArray(result)).toBe(true);
    expect(result).toHaveLength(3);

    if (!Array.isArray(result)) {
      throw new Error(`Expected normalized children to resolve to an array. Received: ${String(result)}`);
    }

    const [prefix, marker, suffix] = result;
    const prefixElement = requireElement<{ children?: ReactNode; text?: string }>(prefix);
    if (prefixElement.type !== MockTextView) {
      throw new Error('Expected the prefix segment to resolve to MockTextView.');
    }
    expect(prefixElement.type).toBe(MockTextView);
    expect(prefixElement.props.text).toBe('alpha beta');

    const markerElement = requireElement<{ label?: string }>(marker);
    if (markerElement.type !== Marker) {
      throw new Error('Expected the marker segment to resolve to Marker.');
    }
    expect(markerElement.type).toBe(Marker);
    expect(markerElement.props.label).toBe('mid');

    const suffixElement = requireElement<{ children?: ReactNode; text?: string }>(suffix);
    if (suffixElement.type !== MockTextView) {
      throw new Error('Expected the suffix segment to resolve to MockTextView.');
    }
    expect(suffixElement.type).toBe(MockTextView);
    expect(suffixElement.props.text).toBe(' gamma');
  });

  it('rejects non-renderable runtime values during child normalization', () => {
    expect(() => Reflect.apply(normalizeTextViewChildren, undefined, [{ value: 1 }, MockTextView])).toThrow(
      'RNTextEngine: TextView child forwarding resolved to a non-text value.'
    );
  });

  it('coerces nullish and boolean text expressions to the empty string', () => {
    expect(coerceTextViewText(null)).toBe('');
    expect(coerceTextViewText(undefined)).toBe('');
    expect(coerceTextViewText(false)).toBe('');
    expect(coerceTextViewText(true)).toBe('');
  });

  it('rejects React elements on the direct text path', () => {
    expect(() => coerceTextViewText(<Marker />)).toThrow('RNTextEngine: TextView text expressions must resolve to text-like values.');
  });
});

function requireElement<Props>(value: unknown): ReactElement<Props> {
  if (!isValidElement<Props>(value)) {
    throw new Error('Expected a React element.');
  }
  return value;
}
