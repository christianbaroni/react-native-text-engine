import { NativeModules } from 'react-native';
import RNTextEngineModule from './NativeRNTextEngine';
import type { GlyphFieldConfig, LayoutOptions, NextTextLine, TextLayout, TextLayoutLines, TextMeasureRun, TextMeasureStyle } from './types';

declare global {
  var __RNTextEngineCreateGlyphField: ((config: GlyphFieldConfig) => number) | undefined;
  var __RNTextEngineInstallRuntime: ((runtimeToken: ArrayBuffer) => boolean) | undefined;
  var __RNTextEngineLayout: ((handle: number, options: LayoutOptions) => TextLayout) | undefined;
  var __RNTextEngineLayoutBatch: ((handles: readonly number[], options: LayoutOptions) => TextLayout[]) | undefined;
  var __RNTextEngineLayoutNextLine: ((handle: number, start: number, width: number) => NextTextLine | null) | undefined;
  var __RNTextEngineLayoutLines: ((handle: number, options: LayoutOptions) => TextLayoutLines) | undefined;
  var __RNTextEngineMeasure:
    | ((text: string, style: TextMeasureStyle | undefined, options: LayoutOptions, runs?: readonly TextMeasureRun[]) => TextLayout)
    | undefined;
  var __RNTextEngineMeasureBatch:
    | ((
        texts: readonly string[],
        style: TextMeasureStyle | undefined,
        options: LayoutOptions,
        runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
      ) => TextLayout[])
    | undefined;
  var __RNTextEngineMeasureWidth:
    | ((text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number)
    | undefined;
  var __RNTextEnginePrepare: ((text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number) | undefined;
  var __RNTextEnginePrepareBatch:
    | ((
        texts: readonly string[],
        style: TextMeasureStyle | undefined,
        runsByText?: readonly (readonly TextMeasureRun[] | undefined)[]
      ) => number[])
    | undefined;
  var __RNTextEngineReleaseGlyphField: ((handle: number) => void) | undefined;
  var __RNTextEngineRelease: ((handle: number) => void) | undefined;
  var __RNTextEngineReleaseMany: ((handles: readonly number[]) => void) | undefined;
  var __RNTextEngineUpdateGlyphField: ((handle: number, glyphs: string, variantIndices: Uint8Array) => void) | undefined;
}

type RNTextEngineRuntime = {
  readonly createGlyphField: (config: GlyphFieldConfig) => number;
  readonly installRuntime: (runtimeToken: ArrayBuffer) => void;
  readonly layout: (handle: number, options: LayoutOptions) => TextLayout;
  readonly layoutBatch: (handles: readonly number[], options: LayoutOptions) => TextLayout[];
  readonly layoutNextLine: (handle: number, start: number, width: number) => NextTextLine | null;
  readonly layoutLines: (handle: number, options: LayoutOptions) => TextLayoutLines;
  readonly measure: (
    text: string,
    style: TextMeasureStyle | undefined,
    options: LayoutOptions,
    runs?: readonly TextMeasureRun[]
  ) => TextLayout;
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

let cachedRuntime: RNTextEngineRuntime | null = null;

function hasInstall(value: unknown): value is { install: () => boolean } {
  if (typeof value !== 'object' || value === null) return false;
  return typeof Reflect.get(value, 'install') === 'function';
}

function resolveInstallModule(): { install: () => boolean } | null {
  if (hasInstall(RNTextEngineModule)) return RNTextEngineModule;

  const nativeModule = NativeModules.RNTextEngine;
  if (hasInstall(nativeModule)) return nativeModule;

  return null;
}

function buildRuntime(): RNTextEngineRuntime {
  const createGlyphField = globalThis.__RNTextEngineCreateGlyphField;
  const installRuntime = globalThis.__RNTextEngineInstallRuntime;
  const prepare = globalThis.__RNTextEnginePrepare;
  const prepareBatch = globalThis.__RNTextEnginePrepareBatch;
  const releaseGlyphField = globalThis.__RNTextEngineReleaseGlyphField;
  const release = globalThis.__RNTextEngineRelease;
  const releaseMany = globalThis.__RNTextEngineReleaseMany;
  const updateGlyphField = globalThis.__RNTextEngineUpdateGlyphField;
  const measureWidth = globalThis.__RNTextEngineMeasureWidth;
  const measure = globalThis.__RNTextEngineMeasure;
  const measureBatch = globalThis.__RNTextEngineMeasureBatch;
  const layout = globalThis.__RNTextEngineLayout;
  const layoutBatch = globalThis.__RNTextEngineLayoutBatch;
  const layoutNextLine = globalThis.__RNTextEngineLayoutNextLine;
  const layoutLines = globalThis.__RNTextEngineLayoutLines;

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
    throw new Error('RNTextEngine: Native runtime installed incompletely. Expected all JSI bindings to be present.');
  }

  return {
    createGlyphField: config => createGlyphField(config),
    installRuntime: runtimeToken => {
      const didInstall = installRuntime(runtimeToken);
      if (!didInstall) {
        throw new Error('RNTextEngine: Failed to install bindings into the requested runtime.');
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

export function initRNTextEngine(): RNTextEngineRuntime {
  if (cachedRuntime) return cachedRuntime;

  try {
    cachedRuntime = buildRuntime();
    return cachedRuntime;
  } catch {
    const installModule = resolveInstallModule();
    if (!installModule) {
      throw new Error(
        'RNTextEngine: Native module was not found. Make sure the package is autolinked and installed in a React Native runtime.'
      );
    }

    const didInstall = installModule.install();
    if (!didInstall) {
      try {
        cachedRuntime = buildRuntime();
        return cachedRuntime;
      } catch {
        throw new Error('RNTextEngine: Native install() returned false.');
      }
    }

    cachedRuntime = buildRuntime();
    return cachedRuntime;
  }
}

export function getRNTextEngineRuntime(): RNTextEngineRuntime {
  return initRNTextEngine();
}
