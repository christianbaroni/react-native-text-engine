import { vi } from 'vitest';
import type {
  GlyphFieldConfig,
  LayoutOptions,
  NextTextLine,
  TextLayout,
  TextLayoutLines,
  TextMeasureRun,
  TextMeasureStyle,
} from '../../src/types';

type RunsByText = readonly (readonly TextMeasureRun[] | undefined)[];

type RuntimeBindingSet = {
  commitGlyphFieldBuffers: ReturnType<typeof vi.fn<(handle: number) => void>>;
  createGlyphField: ReturnType<typeof vi.fn<(config: GlyphFieldConfig) => number>>;
  createGlyphFieldBuffers: ReturnType<typeof vi.fn<(handle: number) => { glyphIndices: ArrayBuffer; variantIndices: ArrayBuffer }>>;
  installWorkletRuntime: ReturnType<typeof vi.fn<(workletRuntime: object) => boolean>>;
  layout: ReturnType<typeof vi.fn<(handle: number, options: LayoutOptions) => TextLayout>>;
  layoutBatch: ReturnType<typeof vi.fn<(handles: readonly number[], options: LayoutOptions) => TextLayout[]>>;
  layoutLines: ReturnType<typeof vi.fn<(handle: number, options: LayoutOptions) => TextLayoutLines>>;
  layoutNextLine: ReturnType<
    typeof vi.fn<(handle: number, start: number, width: number, anchorToCapHeight?: boolean) => NextTextLine | null>
  >;
  measure: ReturnType<
    typeof vi.fn<
      (text: string, style: TextMeasureStyle | undefined, options: LayoutOptions, runs?: readonly TextMeasureRun[]) => TextLayout
    >
  >;
  measureBatch: ReturnType<
    typeof vi.fn<
      (texts: readonly string[], style: TextMeasureStyle | undefined, options: LayoutOptions, runsByText?: RunsByText) => TextLayout[]
    >
  >;
  measureWidth: ReturnType<typeof vi.fn<(text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number>>;
  prepare: ReturnType<typeof vi.fn<(text: string, style: TextMeasureStyle | undefined, runs?: readonly TextMeasureRun[]) => number>>;
  prepareBatch: ReturnType<
    typeof vi.fn<(texts: readonly string[], style: TextMeasureStyle | undefined, runsByText?: RunsByText) => number[]>
  >;
  release: ReturnType<typeof vi.fn<(handle: number) => void>>;
  releaseGlyphField: ReturnType<typeof vi.fn<(handle: number) => void>>;
  releaseMany: ReturnType<typeof vi.fn<(handles: readonly number[]) => void>>;
  updateGlyphField: ReturnType<typeof vi.fn<(handle: number, glyphs: string, variantIndices: Uint8Array) => void>>;
  updateGlyphFieldIndices: ReturnType<typeof vi.fn<(handle: number, glyphIndices: Uint8Array, variantIndices: Uint8Array) => void>>;
};

const DEFAULT_LAYOUT: TextLayout = {
  height: 18,
  lastLineWidth: 72,
  lineCount: 1,
  width: 72,
};

const DEFAULT_LAYOUT_LINES: TextLayoutLines = {
  ...DEFAULT_LAYOUT,
  lines: [
    {
      bottom: 18,
      end: 5,
      index: 0,
      start: 0,
      width: 72,
    },
  ],
};

const DEFAULT_NEXT_LINE: NextTextLine = {
  bottom: 18,
  end: 5,
  start: 0,
  width: 72,
};

function setBinding(name: string, value: unknown): void {
  Reflect.set(globalThis, name, value);
}

export function clearRuntimeBindings(): void {
  const bindingNames = [
    '__RNTextEngineCommitGlyphFieldBuffers',
    '__RNTextEngineCreateGlyphField',
    '__RNTextEngineCreateGlyphFieldBuffers',
    '__RNTextEngineInstallWorkletRuntime',
    '__RNTextEngineLayout',
    '__RNTextEngineLayoutBatch',
    '__RNTextEngineLayoutLines',
    '__RNTextEngineLayoutNextLine',
    '__RNTextEngineMeasure',
    '__RNTextEngineMeasureBatch',
    '__RNTextEngineMeasureWidth',
    '__RNTextEnginePrepare',
    '__RNTextEnginePrepareBatch',
    '__RNTextEngineRelease',
    '__RNTextEngineReleaseGlyphField',
    '__RNTextEngineReleaseMany',
    '__RNTextEngineUpdateGlyphField',
    '__RNTextEngineUpdateGlyphFieldIndices',
  ];

  for (const name of bindingNames) {
    Reflect.deleteProperty(globalThis, name);
  }
}

export function installRuntimeBindings(): RuntimeBindingSet {
  const createGlyphField = vi.fn((config: GlyphFieldConfig) => config.columns * 100 + config.rows);
  const installWorkletRuntime = vi.fn((_workletRuntime: object) => true);
  const prepare = vi.fn((_text: string, _style: TextMeasureStyle | undefined, _runs?: readonly TextMeasureRun[]) => 11);
  const prepareBatch = vi.fn((texts: readonly string[]) => texts.map((_text, index) => 20 + index));
  const releaseGlyphField = vi.fn((_handle: number) => undefined);
  const release = vi.fn((_handle: number) => undefined);
  const releaseMany = vi.fn((_handles: readonly number[]) => undefined);
  const updateGlyphField = vi.fn((_handle: number, _glyphs: string, _variantIndices: Uint8Array) => undefined);
  const updateGlyphFieldIndices = vi.fn((_handle: number, _glyphIndices: Uint8Array, _variantIndices: Uint8Array) => undefined);
  const measureWidth = vi.fn((_text: string, _style: TextMeasureStyle | undefined, _runs?: readonly TextMeasureRun[]) => 72);
  const measure = vi.fn(
    (_text: string, _style: TextMeasureStyle | undefined, _options: LayoutOptions, _runs?: readonly TextMeasureRun[]) => DEFAULT_LAYOUT
  );
  const measureBatch = vi.fn(
    (texts: readonly string[], _style: TextMeasureStyle | undefined, _options: LayoutOptions, _runsByText?: RunsByText) =>
      texts.map((_text, index) => ({
        height: DEFAULT_LAYOUT.height + index,
        lastLineWidth: DEFAULT_LAYOUT.lastLineWidth + index,
        lineCount: DEFAULT_LAYOUT.lineCount,
        width: DEFAULT_LAYOUT.width + index,
      }))
  );
  const layout = vi.fn((_handle: number, _options: LayoutOptions) => DEFAULT_LAYOUT);
  const layoutBatch = vi.fn((handles: readonly number[], _options: LayoutOptions) =>
    handles.map((_handle, index) => ({
      height: DEFAULT_LAYOUT.height + index,
      lastLineWidth: DEFAULT_LAYOUT.lastLineWidth + index,
      lineCount: DEFAULT_LAYOUT.lineCount,
      width: DEFAULT_LAYOUT.width + index,
    }))
  );
  const layoutNextLine = vi.fn((_handle: number, _start: number, _width: number, _anchorToCapHeight?: boolean) => DEFAULT_NEXT_LINE);
  const layoutLines = vi.fn((_handle: number, _options: LayoutOptions) => DEFAULT_LAYOUT_LINES);
  const createGlyphFieldBuffers = vi.fn((_handle: number) => ({
    glyphIndices: new Uint8Array([0, 1, 2]).buffer,
    variantIndices: new Uint8Array([2, 1, 0]).buffer,
  }));
  const commitGlyphFieldBuffers = vi.fn((_handle: number) => undefined);

  setBinding('__RNTextEngineCreateGlyphField', createGlyphField);
  setBinding('__RNTextEngineInstallWorkletRuntime', installWorkletRuntime);
  setBinding('__RNTextEnginePrepare', prepare);
  setBinding('__RNTextEnginePrepareBatch', prepareBatch);
  setBinding('__RNTextEngineReleaseGlyphField', releaseGlyphField);
  setBinding('__RNTextEngineRelease', release);
  setBinding('__RNTextEngineReleaseMany', releaseMany);
  setBinding('__RNTextEngineUpdateGlyphField', updateGlyphField);
  setBinding('__RNTextEngineUpdateGlyphFieldIndices', updateGlyphFieldIndices);
  setBinding('__RNTextEngineMeasureWidth', measureWidth);
  setBinding('__RNTextEngineMeasure', measure);
  setBinding('__RNTextEngineMeasureBatch', measureBatch);
  setBinding('__RNTextEngineLayout', layout);
  setBinding('__RNTextEngineLayoutBatch', layoutBatch);
  setBinding('__RNTextEngineLayoutNextLine', layoutNextLine);
  setBinding('__RNTextEngineLayoutLines', layoutLines);
  setBinding('__RNTextEngineCreateGlyphFieldBuffers', createGlyphFieldBuffers);
  setBinding('__RNTextEngineCommitGlyphFieldBuffers', commitGlyphFieldBuffers);

  return {
    commitGlyphFieldBuffers,
    createGlyphField,
    createGlyphFieldBuffers,
    installWorkletRuntime,
    layout,
    layoutBatch,
    layoutLines,
    layoutNextLine,
    measure,
    measureBatch,
    measureWidth,
    prepare,
    prepareBatch,
    release,
    releaseGlyphField,
    releaseMany,
    updateGlyphField,
    updateGlyphFieldIndices,
  };
}
