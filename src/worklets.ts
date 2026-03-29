import { createWorkletRuntime, getUIRuntimeHolder, runOnUISync, scheduleOnRuntime, type WorkletRuntime } from 'react-native-worklets';
import { getRNTextEngineRuntime } from './initModule';
import type { GlyphFieldHandle, LayoutOptions, PreparedTextHandle, TextLayout, TextMeasureRun, TextMeasureStyle } from './types';

declare global {
  var _WORKLET_RUNTIME: ArrayBuffer;
  var __RNTextEngineInstallWorkletRuntime: ((workletRuntime: object) => boolean) | undefined;
  var __RNTextEngineUpdateGlyphField: ((handle: number, glyphs: string, variantIndices: Uint8Array) => void) | undefined;
}

export type TextEngineRuntimeConfig = {
  animationQueuePollingRate?: number;
  initializer?: () => void;
  name?: string;
  useDefaultQueue?: boolean;
  customQueue?: object;
  enableEventLoop?: true;
};

function buildHandle(id: number): PreparedTextHandle {
  'worklet';
  return { handle: id };
}

/**
 * Installs `react-native-text-engine` into the Reanimated UI runtime.
 *
 * Call this once during app startup before running text-engine calls from UI
 * worklets.
 */
export function installTextEngineInUIRuntime(): void {
  const installWorkletRuntime = globalThis.__RNTextEngineInstallWorkletRuntime;
  if (installWorkletRuntime) {
    const didInstall = installWorkletRuntime(getUIRuntimeHolder());
    if (!didInstall) {
      throw new Error('RNTextEngine: Failed to install bindings into the UI runtime.');
    }
    return;
  }

  const runtimeToken = runOnUISync(() => {
    'worklet';
    return globalThis._WORKLET_RUNTIME;
  });
  getRNTextEngineRuntime().installRuntime(runtimeToken);
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

  const installWorkletRuntime = globalThis.__RNTextEngineInstallWorkletRuntime;
  if (!installWorkletRuntime) {
    throw new Error('RNTextEngine: Native installWorkletRuntime() is unavailable in this build.');
  }

  const didInstall = installWorkletRuntime(workletRuntime);
  if (!didInstall) {
    throw new Error('RNTextEngine: Failed to install bindings into the created worklet runtime.');
  }

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

  return measureBatch(texts, style, options, runsByText);
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

  return prepareBatch(texts, style, runsByText).map(buildHandle);
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

  const updateGlyphField = globalThis.__RNTextEngineUpdateGlyphField;
  if (!updateGlyphField) {
    throw new Error('RNTextEngine: updateGlyphFieldInRuntime() was called before the current runtime was installed.');
  }

  updateGlyphField(typeof handle === 'number' ? handle : handle.handle, glyphs, variantIndices);
}
