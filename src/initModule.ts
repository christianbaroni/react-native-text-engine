import { NativeModules } from 'react-native';
import RNPretextModule from './NativeRNPretext';
import type {
  GlyphFieldConfig,
  LayoutOptions,
  NextTextLine,
  TextLayout,
  TextLayoutLines,
  TextMeasureRun,
  TextMeasureStyle,
} from './types';

declare global {
  var __RNPretextCreateGlyphField: ((config: GlyphFieldConfig) => number) | undefined;
  var __RNPretextInstallRuntime: ((runtimeToken: ArrayBuffer) => boolean) | undefined;
  var __RNPretextLayout: ((handle: number, options: LayoutOptions) => TextLayout) | undefined;
  var __RNPretextLayoutBatch:
    | ((handles: readonly number[], options: LayoutOptions) => TextLayout[])
    | undefined;
  var __RNPretextLayoutNextLine:
    | ((handle: number, start: number, width: number) => NextTextLine | null)
    | undefined;
  var __RNPretextLayoutLines:
    | ((handle: number, options: LayoutOptions) => TextLayoutLines)
    | undefined;
  var __RNPretextMeasure:
    | ((text: string, style: TextMeasureStyle | undefined, options: LayoutOptions, runs?: readonly TextMeasureRun[]) => TextLayout)
    | undefined;
  var __RNPretextMeasureBatch:
    | ((
        texts: readonly string[],
        style: TextMeasureStyle | undefined,
        options: LayoutOptions,
        runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
      ) => TextLayout[])
    | undefined;
  var __RNPretextMeasureWidth:
    | ((text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number)
    | undefined;
  var __RNPretextPrepare:
    | ((text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number)
    | undefined;
  var __RNPretextPrepareBatch:
    | ((
        texts: readonly string[],
        style: TextMeasureStyle | undefined,
        runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
      ) => number[])
    | undefined;
  var __RNPretextReleaseGlyphField: ((handle: number) => void) | undefined;
  var __RNPretextRelease: ((handle: number) => void) | undefined;
  var __RNPretextReleaseMany: ((handles: readonly number[]) => void) | undefined;
  var __RNPretextUpdateGlyphField: ((handle: number, glyphs: string, variantIndices: Uint8Array) => void) | undefined;
}

type RNPretextRuntime = {
  readonly createGlyphField: (config: GlyphFieldConfig) => number;
  readonly installRuntime: (runtimeToken: ArrayBuffer) => void;
  readonly layout: (handle: number, options: LayoutOptions) => TextLayout;
  readonly layoutBatch: (handles: readonly number[], options: LayoutOptions) => TextLayout[];
  readonly layoutNextLine: (handle: number, start: number, width: number) => NextTextLine | null;
  readonly layoutLines: (handle: number, options: LayoutOptions) => TextLayoutLines;
  readonly measure: (text: string, style: TextMeasureStyle | undefined, options: LayoutOptions, runs?: readonly TextMeasureRun[]) => TextLayout;
  readonly measureBatch: (
    texts: readonly string[],
    style: TextMeasureStyle | undefined,
    options: LayoutOptions,
    runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
  ) => TextLayout[];
  readonly measureWidth: (text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number;
  readonly prepare: (text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number;
  readonly prepareBatch: (
    texts: readonly string[],
    style: TextMeasureStyle | undefined,
    runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
  ) => number[];
  readonly releaseGlyphField: (handle: number) => void;
  readonly release: (handle: number) => void;
  readonly releaseMany: (handles: readonly number[]) => void;
  readonly updateGlyphField: (handle: number, glyphs: string, variantIndices: Uint8Array) => void;
};

let cachedRuntime: RNPretextRuntime | null = null;

function hasInstall(value: unknown): value is { install: () => boolean } {
  if (typeof value !== 'object' || value === null) return false;
  return typeof Reflect.get(value, 'install') === 'function';
}

function resolveInstallModule(): { install: () => boolean } | null {
  if (hasInstall(RNPretextModule)) return RNPretextModule;

  const nativeModule = NativeModules.RNPretext;
  if (hasInstall(nativeModule)) return nativeModule;

  return null;
}

function buildRuntime(): RNPretextRuntime {
  const createGlyphField = globalThis.__RNPretextCreateGlyphField;
  const installRuntime = globalThis.__RNPretextInstallRuntime;
  const prepare = globalThis.__RNPretextPrepare;
  const prepareBatch = globalThis.__RNPretextPrepareBatch;
  const releaseGlyphField = globalThis.__RNPretextReleaseGlyphField;
  const release = globalThis.__RNPretextRelease;
  const releaseMany = globalThis.__RNPretextReleaseMany;
  const updateGlyphField = globalThis.__RNPretextUpdateGlyphField;
  const measureWidth = globalThis.__RNPretextMeasureWidth;
  const measure = globalThis.__RNPretextMeasure;
  const measureBatch = globalThis.__RNPretextMeasureBatch;
  const layout = globalThis.__RNPretextLayout;
  const layoutBatch = globalThis.__RNPretextLayoutBatch;
  const layoutNextLine = globalThis.__RNPretextLayoutNextLine;
  const layoutLines = globalThis.__RNPretextLayoutLines;

  if (
    !createGlyphField ||
    !installRuntime ||
    !prepare ||
    !prepareBatch ||
    !releaseGlyphField ||
    !release ||
    !releaseMany ||
    !updateGlyphField ||
    !measureWidth ||
    !measure ||
    !measureBatch ||
    !layout ||
    !layoutBatch ||
    !layoutNextLine ||
    !layoutLines
  ) {
    throw new Error('RNPretext: Native runtime installed incompletely. Expected all JSI bindings to be present.');
  }

  return {
    createGlyphField: config => createGlyphField(config),
    installRuntime: runtimeToken => {
      const didInstall = installRuntime(runtimeToken);
      if (!didInstall) {
        throw new Error('RNPretext: Failed to install bindings into the requested runtime.');
      }
    },
    layout: (handle, options) => layout(handle, options),
    layoutBatch: (handles, options) => layoutBatch(handles, options),
    layoutNextLine: (handle, start, width) => layoutNextLine(handle, start, width),
    layoutLines: (handle, options) => layoutLines(handle, options),
    measure: (text, style, options, runs) => measure(text, style, options, runs),
    measureBatch: (texts, style, options, runsByText) => measureBatch(texts, style, options, runsByText),
    measureWidth: (text, style, runs) => measureWidth(text, style, runs),
    prepare: (text, style, runs) => prepare(text, style, runs),
    prepareBatch: (texts, style, runsByText) => prepareBatch(texts, style, runsByText),
    releaseGlyphField: handle => releaseGlyphField(handle),
    release: handle => release(handle),
    releaseMany: handles => releaseMany(handles),
    updateGlyphField: (handle, glyphs, variantIndices) => updateGlyphField(handle, glyphs, variantIndices),
  };
}

export function initRNPretext(): RNPretextRuntime {
  if (cachedRuntime) return cachedRuntime;

  try {
    cachedRuntime = buildRuntime();
    return cachedRuntime;
  } catch {
    const installModule = resolveInstallModule();
    if (!installModule) {
      throw new Error('RNPretext: Native module was not found. Make sure the package is autolinked and installed in a React Native runtime.');
    }

    const didInstall = installModule.install();
    if (!didInstall) {
      try {
        cachedRuntime = buildRuntime();
        return cachedRuntime;
      } catch {
        throw new Error('RNPretext: Native install() returned false.');
      }
    }

    cachedRuntime = buildRuntime();
    return cachedRuntime;
  }
}

export function getRNPretextRuntime(): RNPretextRuntime {
  return initRNPretext();
}
