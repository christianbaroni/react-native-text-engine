import { render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { clearRuntimeBindings, installRuntimeBindings } from './support/runtimeBindings';
import type { GlyphFieldConfig, LayoutOptions, TextEngineDefaults, TextMeasureRun, TextMeasureStyle } from '../src/types';

const BASE_STYLE: TextMeasureStyle = {
  fontSize: 16,
  lineHeight: 20,
};

const BASE_LAYOUT: LayoutOptions = {
  width: 140,
};

const RESOLVED_BASE_LAYOUT: LayoutOptions = {
  width: 140,
};

const BASE_RUN: TextMeasureRun = {
  end: 5,
  start: 0,
  style: { fontWeight: '700' },
};

const FIELD_CONFIG: GlyphFieldConfig = {
  columns: 3,
  fontSize: 14,
  lineHeight: 16,
  rows: 2,
  variants: [{ color: '#fff' }],
};

type NativeTextViewPayload = Readonly<{
  allowFontScaling?: boolean;
  anchorToCapHeight?: boolean;
  children?: unknown;
  color?: string;
  fontFamily?: string;
  fontSize?: number;
  fontStyle?: string;
  fontWeight?: string;
  letterSpacing?: number;
  lineHeight?: number;
  runColors?: readonly string[];
  runEnds?: readonly number[];
  runFontFamilies?: readonly string[];
  runFontStyles?: readonly string[];
  runFontWeights?: readonly string[];
  runLetterSpacings?: readonly number[];
  runLineHeights?: readonly number[];
  runStarts?: readonly number[];
  runStyleMasks?: readonly number[];
  runTabularNumbers?: readonly boolean[];
  rnteHasAllowFontScaling?: boolean;
  rnteHasLetterSpacing?: boolean;
  rnteHasTabularNumbers?: boolean;
  style?: unknown;
  tabularNumbers?: boolean;
  text?: string;
  textAlign?: string;
  textDecorationColor?: string;
  textDecorationLine?: string;
  textDecorationStyle?: string;
  textTransform?: string;
}>;

type NativePreparedTextViewPayload = Readonly<{
  anchorToCapHeight?: boolean;
  handle?: number;
}>;

async function importIndex() {
  return import('../src/index');
}

function installTextEngineDefaults(defaults: TextEngineDefaults): void {
  vi.doMock('../src/generated/TextEngineAppDefaults', () => ({
    default: defaults,
    textEngineAppDefaults: defaults,
  }));
}

describe('public TS contract', () => {
  beforeEach(async () => {
    vi.resetModules();
    vi.doUnmock('../src/generated/TextEngineAppDefaults');
    clearRuntimeBindings();

    const { resetReactNativeMockState } = await import('./mocks/react-native');
    resetReactNativeMockState();
  });

  it('creates, batches, lays out, and releases prepared text through the installed runtime', async () => {
    const bindings = installRuntimeBindings();
    const { PreparedText, createPreparedText, layoutPreparedText, releasePreparedText } = await importIndex();

    const single = createPreparedText('hello', BASE_STYLE, [BASE_RUN]);
    const batch = createPreparedText(['hello', 'goodbye'], BASE_STYLE, [[BASE_RUN], undefined]);

    expect(single).toBeInstanceOf(PreparedText);
    expect(single.handle).toBe(11);
    expect(batch.map(item => item.handle)).toEqual([20, 21]);
    expect(bindings.prepare).toHaveBeenCalledWith('hello', BASE_STYLE, [BASE_RUN]);
    expect(bindings.prepareBatch).toHaveBeenCalledWith(['hello', 'goodbye'], BASE_STYLE, [[BASE_RUN], undefined]);

    expect(single.layout({ ...BASE_LAYOUT, anchorToCapHeight: true })).toEqual(bindings.layout.mock.results[0]?.value);
    expect(layoutPreparedText(batch, BASE_LAYOUT)).toEqual(bindings.layoutBatch.mock.results[0]?.value);
    expect(single.nextLine(0, BASE_LAYOUT.width, true)).toEqual(bindings.layoutNextLine.mock.results[0]?.value);
    expect(bindings.layout).toHaveBeenCalledWith(11, { ...BASE_LAYOUT, anchorToCapHeight: true });
    expect(bindings.layoutNextLine).toHaveBeenCalledWith(11, 0, BASE_LAYOUT.width, true);

    single.release();
    const firstBatchItem = batch[0];
    if (firstBatchItem === undefined) {
      throw new Error('Expected the prepared-text batch to contain a first handle.');
    }
    releasePreparedText([firstBatchItem]);
    releasePreparedText(batch);

    expect(bindings.release).toHaveBeenCalledTimes(2);
    expect(bindings.release).toHaveBeenNthCalledWith(1, 11);
    expect(bindings.release).toHaveBeenNthCalledWith(2, 20);
    expect(bindings.releaseMany).toHaveBeenCalledWith([20, 21]);
  });

  it('routes measureText and measureTextWidth through the same runtime contract for single and batch inputs', async () => {
    const bindings = installRuntimeBindings();
    const { measureText, measureTextWidth } = await importIndex();

    const single = measureText('alpha', BASE_STYLE, BASE_LAYOUT, [BASE_RUN]);
    const batch = measureText(['alpha', 'beta'], BASE_STYLE, BASE_LAYOUT, [[BASE_RUN], undefined]);
    const width = measureTextWidth('alpha', BASE_STYLE, [BASE_RUN]);

    expect(single).toEqual(bindings.measure.mock.results[0]?.value);
    expect(batch).toEqual(bindings.measureBatch.mock.results[0]?.value);
    expect(width).toBe(72);
    expect(bindings.measure).toHaveBeenCalledWith('alpha', BASE_STYLE, RESOLVED_BASE_LAYOUT, [BASE_RUN]);
    expect(bindings.measureBatch).toHaveBeenCalledWith(['alpha', 'beta'], BASE_STYLE, RESOLVED_BASE_LAYOUT, [[BASE_RUN], undefined]);
    expect(bindings.measureWidth).toHaveBeenCalledWith('alpha', BASE_STYLE, [BASE_RUN]);
  });

  it('applies app-wide defaults anywhere the caller leaves shared text facts unspecified', async () => {
    installTextEngineDefaults({
      anchorToCapHeight: true,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      letterSpacing: 0.2,
      lineHeight: 24,
    });

    const bindings = installRuntimeBindings();
    const { createGlyphField, createPreparedText, measureText, measureTextWidth } = await importIndex();

    const prepared = createPreparedText('hello', { fontWeight: '700' });
    prepared.layout(BASE_LAYOUT);
    prepared.nextLine(0, BASE_LAYOUT.width);
    measureText('alpha', undefined, BASE_LAYOUT, [BASE_RUN]);
    measureTextWidth('alpha');
    createGlyphField({
      columns: 3,
      rows: 2,
      variants: [{ color: '#fff' }],
    });

    expect(bindings.prepare).toHaveBeenCalledWith(
      'hello',
      {
        fontFamily: 'TiemposText-Regular',
        fontSize: 17,
        fontWeight: '700',
        letterSpacing: 0.2,
        lineHeight: 24,
      },
      undefined
    );
    expect(bindings.layout).toHaveBeenCalledWith(11, { ...BASE_LAYOUT, anchorToCapHeight: true });
    expect(bindings.layoutNextLine).toHaveBeenCalledWith(11, 0, BASE_LAYOUT.width, true);
    expect(bindings.measure).toHaveBeenCalledWith(
      'alpha',
      {
        fontFamily: 'TiemposText-Regular',
        fontSize: 17,
        letterSpacing: 0.2,
        lineHeight: 24,
      },
      { ...BASE_LAYOUT, anchorToCapHeight: true },
      [BASE_RUN]
    );
    expect(bindings.measureWidth).toHaveBeenCalledWith(
      'alpha',
      {
        fontFamily: 'TiemposText-Regular',
        fontSize: 17,
        letterSpacing: 0.2,
        lineHeight: 24,
      },
      undefined
    );
    expect(bindings.createGlyphField).toHaveBeenCalledWith({
      columns: 3,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      letterSpacing: 0.2,
      lineHeight: 24,
      rows: 2,
      variants: [{ color: '#fff' }],
    });
  });

  it('rejects single and batch run payload shapes that do not match the public overload contract', async () => {
    installRuntimeBindings();
    const { createPreparedText, measureText } = await importIndex();

    const invalidRunsByText = [[BASE_RUN]];
    const invalidRuns = [BASE_RUN];
    const invalidSingleRunEntry = [BASE_RUN, { end: 6, start: 5 }];
    const invalidBatchRunEntry = [[BASE_RUN], [{ end: 6, start: 5 }]];

    expect(() => Reflect.apply(createPreparedText, undefined, ['hello', BASE_STYLE, invalidRunsByText])).toThrow(
      'RNTextEngine: createPreparedText() expected text runs for a single text input.'
    );
    expect(() => Reflect.apply(createPreparedText, undefined, [['hello'], BASE_STYLE, invalidRuns])).toThrow(
      'RNTextEngine: createPreparedText() expected runs aligned with the batch text input.'
    );
    expect(() => Reflect.apply(measureText, undefined, ['hello', BASE_STYLE, BASE_LAYOUT, invalidRunsByText])).toThrow(
      'RNTextEngine: measureText() expected text runs for a single text input.'
    );
    expect(() => Reflect.apply(measureText, undefined, [['hello'], BASE_STYLE, BASE_LAYOUT, invalidRuns])).toThrow(
      'RNTextEngine: measureText() expected runs aligned with the batch text input.'
    );
    expect(() => Reflect.apply(createPreparedText, undefined, ['hello', BASE_STYLE, invalidSingleRunEntry])).toThrow(
      'RNTextEngine: createPreparedText() expected text runs for a single text input.'
    );
    expect(() => Reflect.apply(createPreparedText, undefined, [['hello'], BASE_STYLE, invalidBatchRunEntry])).toThrow(
      'RNTextEngine: createPreparedText() expected runs aligned with the batch text input.'
    );
    expect(() => Reflect.apply(measureText, undefined, ['hello', BASE_STYLE, BASE_LAYOUT, invalidSingleRunEntry])).toThrow(
      'RNTextEngine: measureText() expected text runs for a single text input.'
    );
    expect(() => Reflect.apply(measureText, undefined, [['hello'], BASE_STYLE, BASE_LAYOUT, invalidBatchRunEntry])).toThrow(
      'RNTextEngine: measureText() expected runs aligned with the batch text input.'
    );
  });

  it('dispatches glyph-field updates by payload kind and releases the native handle explicitly', async () => {
    const bindings = installRuntimeBindings();
    const { GlyphField, createGlyphField } = await importIndex();

    const field = createGlyphField(FIELD_CONFIG);
    const glyphIndices = new Uint8Array([0, 1, 2, 0, 1, 2]);
    const variantIndices = new Uint8Array([0, 0, 0, 0, 0, 0]);

    expect(field).toBeInstanceOf(GlyphField);
    expect(field.handle).toBe(302);

    field.update('ABCDEF', variantIndices);
    field.update(glyphIndices, variantIndices);
    field.release();

    expect(bindings.createGlyphField).toHaveBeenCalledWith(FIELD_CONFIG);
    expect(bindings.updateGlyphField).toHaveBeenCalledWith(302, 'ABCDEF', variantIndices);
    expect(bindings.updateGlyphFieldIndices).toHaveBeenCalledWith(302, glyphIndices, variantIndices);
    expect(bindings.releaseGlyphField).toHaveBeenCalledWith(302);
  });

  it('flattens inline runs once into the canonical TextView run payload', async () => {
    installRuntimeBindings();
    const { TextView, createTextViewRunPayload } = await importIndex();

    const runPayload = createTextViewRunPayload([
      { end: 2, start: 0, style: { color: '#fff', fontWeight: '700', tabularNumbers: true } },
      { end: 4, start: 2, style: { fontFamily: 'Menlo', fontStyle: 'italic' } },
    ]);

    render(<TextView anchorToCapHeight text="ABCD" {...runPayload} />);

    expect(runPayload).toEqual({
      runColors: ['#fff', ''],
      runCount: 2,
      runEnds: [2, 4],
      runFontFamilies: ['', 'Menlo'],
      runFontStyles: ['', 'italic'],
      runFontWeights: ['700', ''],
      runStarts: [0, 2],
      runStyleMasks: [145, 10],
      runTabularNumbers: [true, false],
    });

    expect(screen.getByTestId('RNTextEngineTextView')).toBeTruthy();

    const { getLastNativeComponentProps } = await import('./mocks/react-native');
    const nativeTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(nativeTextView)) {
      throw new Error(`Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativeTextView)}`);
    }

    expect(nativeTextView.anchorToCapHeight).toBe(true);
    expect(nativeTextView.runStarts).toEqual([0, 2]);
    expect(nativeTextView.runEnds).toEqual([2, 4]);
    expect(nativeTextView.runStyleMasks).toEqual([145, 10]);
    expect(nativeTextView.runColors).toEqual(['#fff', '']);
    expect(nativeTextView.runFontFamilies).toEqual(['', 'Menlo']);
    expect(nativeTextView.runFontStyles).toEqual(['', 'italic']);
    expect(nativeTextView.runFontWeights).toEqual(['700', '']);
    expect(nativeTextView.runTabularNumbers).toEqual([true, false]);
  });

  it('forwards anchorToCapHeight through PreparedTextView', async () => {
    installRuntimeBindings();
    const { PreparedTextView } = await importIndex();

    render(<PreparedTextView anchorToCapHeight handle={21} />);

    const { getLastNativeComponentProps } = await import('./mocks/react-native');
    const nativePreparedTextView = getLastNativeComponentProps('RNTextEnginePreparedTextView');
    if (!isNativePreparedTextViewPayload(nativePreparedTextView)) {
      throw new Error(
        `Expected RNTextEnginePreparedTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativePreparedTextView)}`
      );
    }

    expect(nativePreparedTextView.anchorToCapHeight).toBe(true);
    expect(nativePreparedTextView.handle).toBe(21);
  });

  it('projects the shared cap-height default onto direct render surfaces without overriding explicit props', async () => {
    installTextEngineDefaults({
      anchorToCapHeight: true,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      lineHeight: 24,
    });

    installRuntimeBindings();
    const { PreparedTextView, TextView } = await importIndex();

    render(
      <>
        <TextView anchorToCapHeight={false} fontSize={20} text="ABCD" />
        <PreparedTextView handle={21} />
      </>
    );

    const { getLastNativeComponentProps } = await import('./mocks/react-native');
    const nativePreparedTextView = getLastNativeComponentProps('RNTextEnginePreparedTextView');
    if (!isNativePreparedTextViewPayload(nativePreparedTextView)) {
      throw new Error(
        `Expected RNTextEnginePreparedTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativePreparedTextView)}`
      );
    }

    const nativeTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(nativeTextView)) {
      throw new Error(`Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativeTextView)}`);
    }

    expect(nativeTextView.anchorToCapHeight).toBe(false);
    expect(nativeTextView.fontSize).toBe(20);
    expect(nativePreparedTextView.anchorToCapHeight).toBe(true);
  });

  it('projects direct text policy defaults and preserves explicit overrides on TextView', async () => {
    installTextEngineDefaults({
      allowFontScaling: true,
      anchorToCapHeight: true,
      tabularNumbers: true,
    });

    installRuntimeBindings();
    const { TextView } = await importIndex();
    const { getLastNativeComponentProps } = await import('./mocks/react-native');

    const { rerender } = render(<TextView text="1234" />);

    const defaultedTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(defaultedTextView)) {
      throw new Error(
        `Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(defaultedTextView)}`
      );
    }

    expect(defaultedTextView.allowFontScaling).toBe(true);
    expect(defaultedTextView.anchorToCapHeight).toBe(true);
    expect(defaultedTextView.rnteHasAllowFontScaling).toBe(false);
    expect(defaultedTextView.tabularNumbers).toBe(true);
    expect(defaultedTextView.rnteHasTabularNumbers).toBe(false);

    rerender(<TextView allowFontScaling={false} anchorToCapHeight={false} tabularNumbers={false} text="1234" />);

    const explicitTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(explicitTextView)) {
      throw new Error(
        `Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(explicitTextView)}`
      );
    }

    expect(explicitTextView.allowFontScaling).toBe(false);
    expect(explicitTextView.anchorToCapHeight).toBe(false);
    expect(explicitTextView.rnteHasAllowFontScaling).toBe(true);
    expect(explicitTextView.tabularNumbers).toBe(false);
    expect(explicitTextView.rnteHasTabularNumbers).toBe(true);
  });

  it('forwards text decoration props through TextView', async () => {
    installRuntimeBindings();
    const { TextView } = await importIndex();
    const { getLastNativeComponentProps } = await import('./mocks/react-native');

    render(<TextView text="42" textDecorationColor="#ff00ff" textDecorationLine="underline line-through" textDecorationStyle="dashed" />);

    const nativeTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(nativeTextView)) {
      throw new Error(`Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativeTextView)}`);
    }

    expect(nativeTextView.textDecorationColor).toBe('#ff00ff');
    expect(nativeTextView.textDecorationLine).toBe('underline line-through');
    expect(nativeTextView.textDecorationStyle).toBe('dashed');
  });

  it('forwards the textTransform prop through TextView', async () => {
    installRuntimeBindings();
    const { TextView } = await importIndex();
    const { getLastNativeComponentProps } = await import('./mocks/react-native');

    render(<TextView style={{ textTransform: 'uppercase' }} text="gas" textTransform="uppercase" />);

    const nativeTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(nativeTextView)) {
      throw new Error(`Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativeTextView)}`);
    }

    expect(nativeTextView.textTransform).toBe('uppercase');
    expect(nativeTextView.style).toEqual({ textTransform: 'uppercase' });
  });

  it('passes TextView style through untouched instead of resolving text fields in React', async () => {
    installRuntimeBindings();
    const { TextView } = await importIndex();

    render(
      <TextView
        style={{
          color: '#999',
          fontFamily: 'Menlo',
          fontSize: 11,
          fontWeight: '600',
          letterSpacing: 0.28,
          paddingBottom: 24,
          textAlign: 'center',
        }}
        text="42 characters"
      />
    );

    const { getLastNativeComponentProps } = await import('./mocks/react-native');
    const nativeTextView = getLastNativeComponentProps('RNTextEngineTextView');
    if (!isNativeTextViewPayload(nativeTextView)) {
      throw new Error(`Expected RNTextEngineTextView to receive a typed native prop payload. Received: ${JSON.stringify(nativeTextView)}`);
    }

    expect(nativeTextView.text).toBe('42 characters');
    expect(nativeTextView.style).toEqual({
      color: '#999',
      fontFamily: 'Menlo',
      fontSize: 11,
      fontWeight: '600',
      letterSpacing: 0.28,
      paddingBottom: 24,
      textAlign: 'center',
    });
  });

  it('stops sending removed host-view style props across rerenders', async () => {
    installRuntimeBindings();
    const { TextView } = await importIndex();
    const { getLastNativeComponentProps } = await import('./mocks/react-native');

    const { rerender } = render(<TextView style={{ backgroundColor: '#ff00ff' }} text="ABCD" />);

    const styledTextView = getLastNativeComponentProps('RNTextEngineTextView');
    expect(styledTextView?.style).toEqual({ backgroundColor: '#ff00ff' });

    rerender(<TextView text="ABCD" />);

    const plainTextView = getLastNativeComponentProps('RNTextEngineTextView');
    expect(plainTextView?.style).toBeUndefined();
  });
});

function isNativeTextViewPayload(value: unknown): value is NativeTextViewPayload {
  if (!isRecordLike(value)) return false;

  return (
    (value.anchorToCapHeight === undefined || typeof value.anchorToCapHeight === 'boolean') &&
    (value.color === undefined || typeof value.color === 'string') &&
    (value.fontFamily === undefined || typeof value.fontFamily === 'string') &&
    (value.fontSize === undefined || typeof value.fontSize === 'number') &&
    (value.fontStyle === undefined || typeof value.fontStyle === 'string') &&
    (value.fontWeight === undefined || typeof value.fontWeight === 'string') &&
    (value.letterSpacing === undefined || typeof value.letterSpacing === 'number') &&
    (value.lineHeight === undefined || typeof value.lineHeight === 'number') &&
    (value.runColors === undefined || isStringArray(value.runColors)) &&
    (value.runEnds === undefined || isNumberArray(value.runEnds)) &&
    (value.runFontFamilies === undefined || isStringArray(value.runFontFamilies)) &&
    (value.runFontStyles === undefined || isStringArray(value.runFontStyles)) &&
    (value.runFontWeights === undefined || isStringArray(value.runFontWeights)) &&
    (value.runStarts === undefined || isNumberArray(value.runStarts)) &&
    (value.runStyleMasks === undefined || isNumberArray(value.runStyleMasks)) &&
    (value.runTabularNumbers === undefined || isBooleanArray(value.runTabularNumbers)) &&
    (value.text === undefined || typeof value.text === 'string') &&
    (value.textAlign === undefined || typeof value.textAlign === 'string') &&
    (value.textTransform === undefined || typeof value.textTransform === 'string')
  );
}

function isNativePreparedTextViewPayload(value: unknown): value is NativePreparedTextViewPayload {
  if (!isRecordLike(value)) return false;

  return (
    (value.anchorToCapHeight === undefined || typeof value.anchorToCapHeight === 'boolean') &&
    (value.handle === undefined || typeof value.handle === 'number')
  );
}

function isRecordLike(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isStringArray(value: unknown): value is readonly string[] {
  return Array.isArray(value) && value.every(item => typeof item === 'string');
}

function isNumberArray(value: unknown): value is readonly number[] {
  return Array.isArray(value) && value.every(item => typeof item === 'number');
}

function isBooleanArray(value: unknown): value is readonly boolean[] {
  return Array.isArray(value) && value.every(item => typeof item === 'boolean');
}
