import { NativeModules } from 'react-native';
import RNPretextModule from './NativeRNPretext';
import type { LayoutOptions, NextTextLine, TextLayout, TextLayoutLines, TextMeasureStyle } from './types';

declare global {
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
  var __RNPretextMeasure: ((text: string, style: TextMeasureStyle | undefined, options: LayoutOptions) => TextLayout) | undefined;
  var __RNPretextMeasureBatch:
    | ((texts: readonly string[], style: TextMeasureStyle | undefined, options: LayoutOptions) => TextLayout[])
    | undefined;
  var __RNPretextMeasureWidth: ((text: string, style: TextMeasureStyle | undefined) => number) | undefined;
  var __RNPretextPrepare: ((text: string, style: TextMeasureStyle | undefined) => number) | undefined;
  var __RNPretextPrepareBatch:
    | ((texts: readonly string[], style: TextMeasureStyle | undefined) => number[])
    | undefined;
  var __RNPretextRelease: ((handle: number) => void) | undefined;
  var __RNPretextReleaseMany: ((handles: readonly number[]) => void) | undefined;
}

type RNPretextRuntime = {
  readonly installRuntime: (runtimeToken: ArrayBuffer) => void;
  readonly layout: (handle: number, options: LayoutOptions) => TextLayout;
  readonly layoutBatch: (handles: readonly number[], options: LayoutOptions) => TextLayout[];
  readonly layoutNextLine: (handle: number, start: number, width: number) => NextTextLine | null;
  readonly layoutLines: (handle: number, options: LayoutOptions) => TextLayoutLines;
  readonly measure: (text: string, style: TextMeasureStyle | undefined, options: LayoutOptions) => TextLayout;
  readonly measureBatch: (texts: readonly string[], style: TextMeasureStyle | undefined, options: LayoutOptions) => TextLayout[];
  readonly measureWidth: (text: string, style: TextMeasureStyle | undefined) => number;
  readonly prepare: (text: string, style: TextMeasureStyle | undefined) => number;
  readonly prepareBatch: (texts: readonly string[], style: TextMeasureStyle | undefined) => number[];
  readonly release: (handle: number) => void;
  readonly releaseMany: (handles: readonly number[]) => void;
};

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
  const installRuntime = globalThis.__RNPretextInstallRuntime;
  const prepare = globalThis.__RNPretextPrepare;
  const prepareBatch = globalThis.__RNPretextPrepareBatch;
  const release = globalThis.__RNPretextRelease;
  const releaseMany = globalThis.__RNPretextReleaseMany;
  const measureWidth = globalThis.__RNPretextMeasureWidth;
  const measure = globalThis.__RNPretextMeasure;
  const measureBatch = globalThis.__RNPretextMeasureBatch;
  const layout = globalThis.__RNPretextLayout;
  const layoutBatch = globalThis.__RNPretextLayoutBatch;
  const layoutNextLine = globalThis.__RNPretextLayoutNextLine;
  const layoutLines = globalThis.__RNPretextLayoutLines;

  if (!installRuntime || !prepare || !prepareBatch || !release || !releaseMany || !measureWidth || !measure || !measureBatch || !layout || !layoutBatch || !layoutNextLine || !layoutLines) {
    throw new Error('RNPretext: Native runtime installed incompletely. Expected all JSI bindings to be present.');
  }

  return {
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
    measure: (text, style, options) => measure(text, style, options),
    measureBatch: (texts, style, options) => measureBatch(texts, style, options),
    measureWidth: (text, style) => measureWidth(text, style),
    prepare: (text, style) => prepare(text, style),
    prepareBatch: (texts, style) => prepareBatch(texts, style),
    release: handle => release(handle),
    releaseMany: handles => releaseMany(handles),
  };
}

export function initRNPretext(): RNPretextRuntime {
  try {
    return buildRuntime();
  } catch {
    const installModule = resolveInstallModule();
    if (!installModule) {
      throw new Error('RNPretext: Native module was not found. Make sure the package is autolinked and installed in a React Native runtime.');
    }

    const didInstall = installModule.install();
    if (!didInstall) {
      try {
        return buildRuntime();
      } catch {
        throw new Error('RNPretext: Native install() returned false.');
      }
    }

    return buildRuntime();
  }
}

export function getRNPretextRuntime(): RNPretextRuntime {
  return initRNPretext();
}
