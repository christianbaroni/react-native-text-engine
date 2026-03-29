import { getRNTextEngineRuntime } from './initModule';
import type {
  LayoutOptions,
  NextTextLine,
  PreparedTextHandle,
  TextLayout,
  TextLayoutLines,
  TextMeasureRun,
  TextMeasureStyle,
} from './types';

type RunsByText = readonly (readonly TextMeasureRun[] | undefined)[];

function buildPreparedText(handle: number): PreparedText {
  return PreparedText.fromHandle(handle);
}

function toNativeHandles(handles: readonly PreparedTextHandle[]): number[] {
  const nativeHandles = new Array<number>(handles.length);
  for (let index = 0; index < handles.length; index += 1) {
    nativeHandles[index] = handles[index]?.handle ?? 0;
  }
  return nativeHandles;
}

function isTextRun(value: unknown): value is TextMeasureRun {
  if (typeof value !== 'object' || value === null) return false;
  return 'start' in value && 'end' in value && 'style' in value;
}

function firstDefined(values: readonly unknown[]): unknown {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (value !== undefined) return value;
  }
  return undefined;
}

function isRuns(value: unknown): value is readonly TextMeasureRun[] {
  if (!Array.isArray(value)) return false;
  const first = firstDefined(value);
  return first === undefined || isTextRun(first);
}

function isRunsByText(value: unknown): value is RunsByText {
  if (!Array.isArray(value)) return false;
  const first = firstDefined(value);
  return first === undefined || Array.isArray(first);
}

function isPreparedTextHandleArray(value: PreparedTextHandle | readonly PreparedTextHandle[]): value is readonly PreparedTextHandle[] {
  return Array.isArray(value);
}

export class PreparedText implements PreparedTextHandle {
  readonly handle: number;

  private constructor(handle: number) {
    this.handle = handle;
  }

  static fromHandle(handle: number): PreparedText {
    return new PreparedText(handle);
  }

  layout(options: LayoutOptions): TextLayout {
    return getRNTextEngineRuntime().layout(this.handle, options);
  }

  lines(options: LayoutOptions): TextLayoutLines {
    return getRNTextEngineRuntime().layoutLines(this.handle, options);
  }

  nextLine(start: number, width: number): NextTextLine | null {
    return getRNTextEngineRuntime().layoutNextLine(this.handle, start, width);
  }

  release(): void {
    getRNTextEngineRuntime().release(this.handle);
  }
}

export function createPreparedText(text: string, style?: TextMeasureStyle, runs?: readonly TextMeasureRun[]): PreparedText;
export function createPreparedText(texts: readonly string[], style?: TextMeasureStyle, runsByText?: RunsByText): PreparedText[];
export function createPreparedText(
  textOrTexts: string | readonly string[],
  style?: TextMeasureStyle,
  runs?: readonly TextMeasureRun[] | RunsByText
): PreparedText | PreparedText[] {
  const runtime = getRNTextEngineRuntime();

  if (typeof textOrTexts === 'string') {
    if (runs !== undefined && !isRuns(runs)) {
      throw new Error('RNTextEngine: createPreparedText() expected text runs for a single text input.');
    }
    return buildPreparedText(runtime.prepare(textOrTexts, style, runs));
  }

  if (runs !== undefined && !isRunsByText(runs)) {
    throw new Error('RNTextEngine: createPreparedText() expected runs aligned with the batch text input.');
  }
  return runtime.prepareBatch(textOrTexts, style, runs).map(buildPreparedText);
}

export function measureTextWidth(text: string, style?: TextMeasureStyle, runs?: readonly TextMeasureRun[]): number {
  return getRNTextEngineRuntime().measureWidth(text, style, runs);
}

export function measureText(
  text: string,
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runs?: readonly TextMeasureRun[]
): TextLayout;
export function measureText(
  texts: readonly string[],
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runsByText?: RunsByText
): TextLayout[];
export function measureText(
  textOrTexts: string | readonly string[],
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runs?: readonly TextMeasureRun[] | RunsByText
): TextLayout | TextLayout[] {
  const runtime = getRNTextEngineRuntime();

  if (typeof textOrTexts === 'string') {
    if (runs !== undefined && !isRuns(runs)) {
      throw new Error('RNTextEngine: measureText() expected text runs for a single text input.');
    }
    return runtime.measure(textOrTexts, style, options, runs);
  }

  if (runs !== undefined && !isRunsByText(runs)) {
    throw new Error('RNTextEngine: measureText() expected runs aligned with the batch text input.');
  }
  return runtime.measureBatch(textOrTexts, style, options, runs);
}

export function layoutPreparedText(handle: PreparedTextHandle, options: LayoutOptions): TextLayout;
export function layoutPreparedText(handles: readonly PreparedTextHandle[], options: LayoutOptions): TextLayout[];
export function layoutPreparedText(
  handleOrHandles: PreparedTextHandle | readonly PreparedTextHandle[],
  options: LayoutOptions
): TextLayout | TextLayout[] {
  const runtime = getRNTextEngineRuntime();
  if (!isPreparedTextHandleArray(handleOrHandles)) {
    return runtime.layout(handleOrHandles.handle, options);
  }
  if (handleOrHandles.length === 0) return [];
  return runtime.layoutBatch(toNativeHandles(handleOrHandles), options);
}

export function releasePreparedText(handle: PreparedTextHandle): void;
export function releasePreparedText(handles: readonly PreparedTextHandle[]): void;
export function releasePreparedText(handleOrHandles: PreparedTextHandle | readonly PreparedTextHandle[]): void {
  const runtime = getRNTextEngineRuntime();
  if (!isPreparedTextHandleArray(handleOrHandles)) {
    runtime.release(handleOrHandles.handle);
    return;
  }
  if (handleOrHandles.length === 0) return;
  if (handleOrHandles.length === 1) {
    runtime.release(handleOrHandles[0]?.handle ?? 0);
    return;
  }
  runtime.releaseMany(toNativeHandles(handleOrHandles));
}
