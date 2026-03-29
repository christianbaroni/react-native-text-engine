import { getRNPretextRuntime } from './initModule';
import { PreparedTextView } from './PreparedTextView';
import { TextView } from './TextView';
import type { LayoutOptions, NextTextLine, PreparedTextHandle, TextLayout, TextLayoutLines, TextMeasureRun, TextMeasureStyle } from './types';

export type { LayoutOptions, NextTextLine, PreparedTextHandle, TextLayout, TextLayoutLines, TextLine, TextMeasureRun, TextMeasureRunStyle, TextMeasureStyle } from './types';
export type { PreparedTextViewProps } from './PreparedTextView';
export type { TextViewProps } from './TextView';
export { PreparedTextView };
export { TextView };

function buildHandle(id: number): PreparedTextHandle {
  return { id };
}

/**
 * Prepares a text block for repeated native layout queries.
 *
 * The returned handle is opaque and must be released when the caller no longer
 * needs it. `runs` extends the base style within sorted, non-overlapping
 * UTF-16 ranges.
 */
export function prepare(text: string, style?: TextMeasureStyle, runs?: readonly TextMeasureRun[]): PreparedTextHandle {
  return buildHandle(getRNPretextRuntime().prepare(text, style, runs));
}

/**
 * Prepares many text blocks with the same measurement style in one native call.
 *
 * `runsByText` must align with `texts` when provided. Each entry may be
 * omitted when that text uses only the base style.
 */
export function prepareBatch(
  texts: readonly string[],
  style?: TextMeasureStyle,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): PreparedTextHandle[] {
  return getRNPretextRuntime().prepareBatch(texts, style, runsByText).map(buildHandle);
}

/**
 * Releases one prepared text handle.
 */
export function release(handle: PreparedTextHandle): void {
  getRNPretextRuntime().release(handle.id);
}

/**
 * Releases many prepared text handles in one native call.
 */
export function releaseMany(handles: readonly PreparedTextHandle[]): void {
  getRNPretextRuntime().releaseMany(handles.map(handle => handle.id));
}

/**
 * Measures the width of one single-line text run synchronously.
 *
 * When `runs` are provided, the returned width reflects their combined inline
 * styling against the base style.
 */
export function measureWidth(text: string, style?: TextMeasureStyle, runs?: readonly TextMeasureRun[]): number {
  return getRNPretextRuntime().measureWidth(text, style, runs);
}

/**
 * Measures one text block directly without keeping a prepared handle.
 */
export function measure(
  text: string,
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runs?: readonly TextMeasureRun[]
): TextLayout {
  return getRNPretextRuntime().measure(text, style, options, runs);
}

/**
 * Measures many text blocks directly without keeping prepared handles.
 */
export function measureBatch(
  texts: readonly string[],
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): TextLayout[] {
  return getRNPretextRuntime().measureBatch(texts, style, options, runsByText);
}

/**
 * Lays out one prepared text block at the given width.
 */
export function layout(handle: PreparedTextHandle, options: LayoutOptions): TextLayout {
  return getRNPretextRuntime().layout(handle.id, options);
}

/**
 * Lays out many prepared text blocks at the given width in one native call.
 */
export function layoutBatch(handles: readonly PreparedTextHandle[], options: LayoutOptions): TextLayout[] {
  return getRNPretextRuntime().layoutBatch(
    handles.map(handle => handle.id),
    options
  );
}

/**
 * Lays out the next visible line beginning at an absolute UTF-16 text offset.
 *
 * Returns `null` when the prepared text is exhausted.
 */
export function layoutNextLine(handle: PreparedTextHandle, start: number, width: number): NextTextLine | null {
  return getRNPretextRuntime().layoutNextLine(handle.id, start, width);
}

/**
 * Lays out one prepared text block and returns per-line geometry.
 */
export function layoutLines(handle: PreparedTextHandle, options: LayoutOptions): TextLayoutLines {
  return getRNPretextRuntime().layoutLines(handle.id, options);
}
