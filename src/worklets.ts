import { createWorkletRuntime, getUIRuntimeHolder, runOnUISync, scheduleOnRuntime, type WorkletRuntime } from 'react-native-worklets';
import { getRNPretextRuntime } from './initModule';
import type { GlyphFieldHandle, LayoutOptions, PreparedTextHandle, TextLayout, TextMeasureRun, TextMeasureStyle } from './types';

declare global {
  var _WORKLET_RUNTIME: ArrayBuffer;
  var __RNPretextInstallWorkletRuntime: ((workletRuntime: object) => boolean) | undefined;
  var __RNPretextUpdateGlyphField: ((handle: number, glyphs: string, variantIndices: Uint8Array) => void) | undefined;
}

export type PretextWorkletRuntimeConfig = {
  animationQueuePollingRate?: number;
  initializer?: () => void;
  name?: string;
  useDefaultQueue?: boolean;
  customQueue?: object;
  enableEventLoop?: true;
};

function buildHandle(id: number): PreparedTextHandle {
  'worklet';
  return { id };
}

/**
 * Installs `react-native-pretext` into the Reanimated UI runtime.
 *
 * Call this once during app startup before running pretext calls from UI
 * worklets.
 */
export function installRNPretextInUIRuntime(): void {
  const installWorkletRuntime = globalThis.__RNPretextInstallWorkletRuntime;
  if (installWorkletRuntime) {
    const didInstall = installWorkletRuntime(getUIRuntimeHolder());
    if (!didInstall) {
      throw new Error('RNPretext: Failed to install bindings into the UI runtime.');
    }
    return;
  }

  const runtimeToken = runOnUISync(() => {
    'worklet';
    return globalThis._WORKLET_RUNTIME;
  });
  getRNPretextRuntime().installRuntime(runtimeToken);
}

/**
 * Creates a dedicated Worklets runtime and installs `react-native-pretext`
 * into it before any caller initializer runs.
 */
export function createRNPretextWorkletRuntime(config?: PretextWorkletRuntimeConfig): WorkletRuntime {
  getRNPretextRuntime();

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

  const installWorkletRuntime = globalThis.__RNPretextInstallWorkletRuntime;
  if (!installWorkletRuntime) {
    throw new Error('RNPretext: Native installWorkletRuntime() is unavailable in this build.');
  }

  const didInstall = installWorkletRuntime(workletRuntime);
  if (!didInstall) {
    throw new Error('RNPretext: Failed to install bindings into the created worklet runtime.');
  }

  if (initializer) scheduleOnRuntime(workletRuntime, initializer);

  return workletRuntime;
}

/**
 * Worklet-safe exact batch measurement against the current installed runtime.
 *
 * This must be called only after `react-native-pretext` has been installed into
 * the current runtime.
 */
export function measureBatchInRuntime(
  texts: readonly string[],
  style: TextMeasureStyle | undefined,
  options: LayoutOptions,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): TextLayout[] {
  'worklet';

  const measureBatch = globalThis.__RNPretextMeasureBatch;
  if (!measureBatch) {
    throw new Error('RNPretext: measureBatchInRuntime() was called before the current runtime was installed.');
  }

  return measureBatch(texts, style, options, runsByText);
}

/**
 * Worklet-safe prepared-text creation against the current installed runtime.
 */
export function prepareBatchInRuntime(
  texts: readonly string[],
  style?: TextMeasureStyle,
  runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
): PreparedTextHandle[] {
  'worklet';

  const prepareBatch = globalThis.__RNPretextPrepareBatch;
  if (!prepareBatch) {
    throw new Error('RNPretext: prepareBatchInRuntime() was called before the current runtime was installed.');
  }

  return prepareBatch(texts, style, runsByText).map(buildHandle);
}

/**
 * Worklet-safe prepared-text layout against the current installed runtime.
 */
export function layoutBatchInRuntime(handles: readonly PreparedTextHandle[], options: LayoutOptions): TextLayout[] {
  'worklet';

  const layoutBatch = globalThis.__RNPretextLayoutBatch;
  if (!layoutBatch) {
    throw new Error('RNPretext: layoutBatchInRuntime() was called before the current runtime was installed.');
  }

  const ids = new Array<number>(handles.length);
  for (let index = 0; index < handles.length; index += 1) {
    ids[index] = handles[index]?.id ?? 0;
  }

  return layoutBatch(ids, options);
}

/**
 * Worklet-safe glyph-field update against the current installed runtime.
 */
export function updateGlyphFieldInRuntime(
  handle: GlyphFieldHandle | number,
  glyphs: string,
  variantIndices: Uint8Array
): void {
  'worklet';

  const updateGlyphField = globalThis.__RNPretextUpdateGlyphField;
  if (!updateGlyphField) {
    throw new Error('RNPretext: updateGlyphFieldInRuntime() was called before the current runtime was installed.');
  }

  updateGlyphField(typeof handle === 'number' ? handle : handle.id, glyphs, variantIndices);
}
