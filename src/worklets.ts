import { createWorkletRuntime, getUIRuntimeHolder, isRNRuntime, scheduleOnRuntime, type WorkletRuntime } from 'react-native-worklets';
import { getRNTextEngineRuntime } from './initModule';
import { resolveAnchorToCapHeight, resolveLayoutOptions, resolveTextMeasureStyle } from './textEngineDefaults';
import type {
  GlyphFieldHandle,
  LayoutOptions,
  NextTextLine,
  PreparedTextHandle,
  TextLayout,
  TextMeasureRun,
  TextMeasureStyle,
} from './types';
import { installTextEngineRuntime, installTextEngineUIRuntime } from './workletRuntimeInstall';

declare global {
  var __RNTextEngineCommitGlyphFieldBuffers: ((handle: number) => void) | undefined;
  var __RNTextEngineCreateGlyphFieldBuffers: ((handle: number) => { glyphIndices: ArrayBuffer; variantIndices: ArrayBuffer }) | undefined;
  var __RNTextEngineUpdateGlyphField: ((handle: number, glyphs: string, variantIndices: Uint8Array) => void) | undefined;
  var __RNTextEngineUpdateGlyphFieldIndices: ((handle: number, glyphIndices: Uint8Array, variantIndices: Uint8Array) => void) | undefined;
}

export type TextEngineRuntimeConfig = {
  animationQueuePollingRate?: number;
  initializer?: () => void;
  name?: string;
  useDefaultQueue?: boolean;
  customQueue?: object;
  enableEventLoop?: true;
};

export type GlyphFieldRuntimeBuffers = {
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
};

function buildHandle(id: number): PreparedTextHandle {
  'worklet';
  return { handle: id };
}

/**
 * Creates a dedicated Worklets runtime and installs `react-native-text-engine`
 * into it before any caller initializer runs.
 */
export function createTextEngineRuntime(config?: TextEngineRuntimeConfig): WorkletRuntime {
  getRNTextEngineRuntime();

  const initializer = config?.initializer;
  const workletRuntime =
    config?.useDefaultQueue === false
      ? createWorkletRuntime({
          animationQueuePollingRate: config.animationQueuePollingRate,
          customQueue: config.customQueue,
          enableEventLoop: config.enableEventLoop,
          name: config.name,
          useDefaultQueue: false,
        })
      : createWorkletRuntime({
          animationQueuePollingRate: config?.animationQueuePollingRate,
          enableEventLoop: config?.enableEventLoop,
          name: config?.name,
        });

  installTextEngineRuntime(workletRuntime, 'created worklet');

  if (initializer) scheduleOnRuntime(workletRuntime, initializer);

  return workletRuntime;
}

/**
 * Worklet-safe exact batch measurement against the current installed runtime.
 *
 * This must be called only after `react-native-text-engine` has been installed into
 * the current runtime.
 */
export function measureTextsInRuntime(
  texts: readonly string[],
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): TextLayout[] {
  'worklet';

  const measureBatch = globalThis.__RNTextEngineMeasureBatch;
  if (!measureBatch) {
    throw new Error('RNTextEngine: measureTextsInRuntime() was called before the current runtime was installed.');
  }

  return measureBatch(texts, resolveTextMeasureStyle(style), resolveLayoutOptions(options), runsByText);
}

/**
 * Worklet-safe prepared-text creation against the current installed runtime.
 */
export function createPreparedTextsInRuntime(
  texts: readonly string[],
  style?: TextMeasureStyle,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): PreparedTextHandle[] {
  'worklet';

  const prepareBatch = globalThis.__RNTextEnginePrepareBatch;
  if (!prepareBatch) {
    throw new Error('RNTextEngine: createPreparedTextsInRuntime() was called before the current runtime was installed.');
  }

  return prepareBatch(texts, resolveTextMeasureStyle(style), runsByText).map(buildHandle);
}

/**
 * Worklet-safe prepared-text layout against the current installed runtime.
 */
export function layoutPreparedTextsInRuntime(handles: readonly PreparedTextHandle[], options: LayoutOptions): TextLayout[] {
  'worklet';

  const layoutBatch = globalThis.__RNTextEngineLayoutBatch;
  if (!layoutBatch) {
    throw new Error('RNTextEngine: layoutPreparedTextsInRuntime() was called before the current runtime was installed.');
  }

  const ids = new Array<number>(handles.length);
  for (let index = 0; index < handles.length; index += 1) {
    ids[index] = handles[index]?.handle ?? 0;
  }

  return layoutBatch(ids, resolveLayoutOptions(options));
}

/**
 * Worklet-safe single-line layout against the current installed runtime.
 *
 * Use this when line width changes one line at a time, such as flowing text
 * around animated obstacles.
 */
export function layoutNextLineInRuntime(
  handle: PreparedTextHandle | number,
  start: number,
  width: number,
  anchorToCapHeight?: boolean
): NextTextLine | null {
  'worklet';

  const layoutNextLine = globalThis.__RNTextEngineLayoutNextLine;
  if (!layoutNextLine) {
    throw new Error('RNTextEngine: layoutNextLineInRuntime() was called before the current runtime was installed.');
  }

  const resolvedHandle = typeof handle === 'number' ? handle : handle.handle;

  return layoutNextLine(resolvedHandle, start, width, resolveAnchorToCapHeight(anchorToCapHeight));
}

/**
 * Worklet-safe glyph-field update against the current installed runtime.
 */
export function updateGlyphFieldInRuntime(handle: GlyphFieldHandle | number, glyphs: string, variantIndices: Uint8Array): void;
export function updateGlyphFieldInRuntime(handle: GlyphFieldHandle | number, glyphIndices: Uint8Array, variantIndices: Uint8Array): void;
export function updateGlyphFieldInRuntime(
  handle: GlyphFieldHandle | number,
  glyphsOrIndices: string | Uint8Array,
  variantIndices: Uint8Array
): void {
  'worklet';

  const resolvedHandle = typeof handle === 'number' ? handle : handle.handle;
  if (typeof glyphsOrIndices === 'string') {
    const updateGlyphField = globalThis.__RNTextEngineUpdateGlyphField;
    if (!updateGlyphField) {
      throw new Error('RNTextEngine: updateGlyphFieldInRuntime() was called before the current runtime was installed.');
    }

    updateGlyphField(resolvedHandle, glyphsOrIndices, variantIndices);
    return;
  }

  const updateGlyphFieldIndices = globalThis.__RNTextEngineUpdateGlyphFieldIndices;
  if (!updateGlyphFieldIndices) {
    throw new Error('RNTextEngine: updateGlyphFieldInRuntime() was called before the current runtime was installed.');
  }

  updateGlyphFieldIndices(resolvedHandle, glyphsOrIndices, variantIndices);
}

export function createGlyphFieldBuffersInRuntime(handle: GlyphFieldHandle | number): GlyphFieldRuntimeBuffers {
  'worklet';

  const createGlyphFieldBuffers = globalThis.__RNTextEngineCreateGlyphFieldBuffers;
  if (!createGlyphFieldBuffers) {
    throw new Error('RNTextEngine: createGlyphFieldBuffersInRuntime() was called before the current runtime was installed.');
  }

  const resolvedHandle = typeof handle === 'number' ? handle : handle.handle;
  const buffers = createGlyphFieldBuffers(resolvedHandle);
  return {
    glyphIndices: new Uint8Array(buffers.glyphIndices),
    variantIndices: new Uint8Array(buffers.variantIndices),
  };
}

export function commitGlyphFieldBuffersInRuntime(handle: GlyphFieldHandle | number): void {
  'worklet';

  const commitGlyphFieldBuffers = globalThis.__RNTextEngineCommitGlyphFieldBuffers;
  if (!commitGlyphFieldBuffers) {
    throw new Error('RNTextEngine: commitGlyphFieldBuffersInRuntime() was called before the current runtime was installed.');
  }

  const resolvedHandle = typeof handle === 'number' ? handle : handle.handle;
  commitGlyphFieldBuffers(resolvedHandle);
}

if (isRNRuntime()) installTextEngineUIRuntime(getUIRuntimeHolder());
