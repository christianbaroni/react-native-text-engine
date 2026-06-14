import { measureTextWidth, type TextMeasureStyle } from 'react-native-text-engine';
import { IS_IOS } from '../constants';

type FontStyleVariant = 'italic' | 'normal';

export type TextFieldConfig = {
  artHeight: number;
  artWidth: number;
  cols: number;
  rows: number;
};

export type TextFieldPointer = {
  active: boolean;
  x: number;
  y: number;
};

export type TextFieldRuntimeInput = {
  cellAmbientBrightness: Float32Array;
  cellCount: number;
  cellDiagonalWaveCos: Float32Array;
  cellDiagonalWaveSin: Float32Array;
  cellVerticalWaveCos: Float32Array;
  cellVerticalWaveSin: Float32Array;
  cellHorizontalWaveCos: Float32Array;
  cellHorizontalWaveSin: Float32Array;
  cellXs: Float32Array;
  cellYs: Float32Array;
  lookupGlyphIndices: Uint8Array;
  lookupVariantIndices: Uint8Array;
  height: number;
  width: number;
};

type WorkletContextValue<T> = {
  __workletContextObject: true;
  current: T;
};

export type TextFieldVariant = {
  color: string;
  fontStyle: FontStyleVariant;
  fontWeight: string;
  key: string;
};

export type TextFieldFrame = {
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
};

export type TextFieldFrameBuffer = WorkletContextValue<{
  emitters: Float32Array;
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
}>;

type PaletteEntry = {
  brightness: number;
  char: string;
  fontStyle: FontStyleVariant;
  fontWeight: string;
  width: number;
};

type LookupTable = {
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
};

const FONT_FAMILY = IS_IOS ? 'Georgia' : 'serif';
const CHARSET = ' .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const WEIGHTS = ['300', '500', '800'] as const;
const STYLES = ['normal', 'italic'] as const;
const BASE_COLOR = 'rgba(196,163,90,0.18)';
const ALPHAS = [0.18, 0.36, 0.62, 0.92] as const;
const VARIANT_COUNT = WEIGHTS.length * STYLES.length;

export const FIELD_STYLE: TextMeasureStyle = {
  color: BASE_COLOR,
  fontFamily: FONT_FAMILY,
  fontSize: 18,
  fontWeight: '300',
  letterSpacing: 0.04,
  lineHeight: 20,
};

export const FIELD_GLYPH_PALETTE = CHARSET;

export const FIELD_VARIANTS: readonly TextFieldVariant[] = ALPHAS.flatMap((alpha, alphaIndex) =>
  STYLES.flatMap(fontStyle =>
    WEIGHTS.map(fontWeight => ({
      color: `rgba(196,163,90,${alpha})`,
      fontStyle,
      fontWeight,
      key: `${alphaIndex}-${fontWeight}-${fontStyle}`,
    }))
  )
);

function clampNumber(value: number, min: number, max: number): number {
  'worklet';
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function clampInt(value: number, min: number, max: number): number {
  'worklet';
  return Math.round(clampNumber(value, min, max));
}

function smoothstep(edge0: number, edge1: number, value: number): number {
  'worklet';
  const x = clampNumber((value - edge0) / (edge1 - edge0), 0, 1);
  return x * x * (3 - 2 * x);
}

const palette = createPalette();

export function resolveTextFieldConfig(width: number, height: number): TextFieldConfig {
  const artWidth = Math.max(320, width - 18);
  const targetCols = Math.round(artWidth / 12.2);
  const cols = clampInt(targetCols, 30, 38);
  const lineHeight = FIELD_STYLE.lineHeight ?? 20;
  const availableHeight = Math.max(360, height - 184);
  const rows = clampInt(Math.floor(availableHeight / lineHeight), 22, 28);

  return {
    artHeight: rows * lineHeight,
    artWidth,
    cols,
    rows,
  };
}

export function createTextFieldRuntimeInput(config: TextFieldConfig): TextFieldRuntimeInput {
  const cellCount = config.rows * config.cols;
  const cellWidth = config.artWidth / config.cols;
  const cellHeight = config.artHeight / config.rows;
  const centerX = config.artWidth * 0.5;
  const centerY = config.artHeight * 0.5;

  const cellXs = new Float32Array(cellCount);
  const cellYs = new Float32Array(cellCount);
  const cellAmbientBrightness = new Float32Array(cellCount);
  const cellHorizontalWaveSin = new Float32Array(cellCount);
  const cellHorizontalWaveCos = new Float32Array(cellCount);
  const cellVerticalWaveSin = new Float32Array(cellCount);
  const cellVerticalWaveCos = new Float32Array(cellCount);
  const cellDiagonalWaveSin = new Float32Array(cellCount);
  const cellDiagonalWaveCos = new Float32Array(cellCount);

  const lookup = createLookup(cellWidth);

  let cellIndex = 0;
  for (let rowIndex = 0; rowIndex < config.rows; rowIndex += 1) {
    const y = (rowIndex + 0.5) * cellHeight;
    const normalizedY = (y - centerY) / config.artHeight;
    const verticalWave = normalizedY * 14.5;

    for (let colIndex = 0; colIndex < config.cols; colIndex += 1) {
      const x = (colIndex + 0.5) * cellWidth;
      const normalizedX = (x - centerX) / config.artWidth;
      const horizontalWave = normalizedX * 10.5;
      const diagonalWave = (normalizedX + normalizedY) * 18.0;
      const vignette = 1 - smoothstep(0.1, 0.68, Math.hypot(normalizedX * 1.02, normalizedY * 1.28));

      cellXs[cellIndex] = x;
      cellYs[cellIndex] = y;
      cellAmbientBrightness[cellIndex] = vignette * 0.06;
      cellHorizontalWaveSin[cellIndex] = Math.sin(horizontalWave);
      cellHorizontalWaveCos[cellIndex] = Math.cos(horizontalWave);
      cellVerticalWaveSin[cellIndex] = Math.sin(verticalWave);
      cellVerticalWaveCos[cellIndex] = Math.cos(verticalWave);
      cellDiagonalWaveSin[cellIndex] = Math.sin(diagonalWave);
      cellDiagonalWaveCos[cellIndex] = Math.cos(diagonalWave);
      cellIndex += 1;
    }
  }

  return {
    cellAmbientBrightness,
    cellCount,
    cellDiagonalWaveCos,
    cellDiagonalWaveSin,
    cellHorizontalWaveCos,
    cellHorizontalWaveSin,
    cellVerticalWaveCos,
    cellVerticalWaveSin,
    cellXs,
    cellYs,
    height: config.artHeight,
    lookupGlyphIndices: lookup.glyphIndices,
    lookupVariantIndices: lookup.variantIndices,
    width: config.artWidth,
  };
}

export function createTextFieldFrameBuffer(cellCount: number): TextFieldFrameBuffer {
  'worklet';
  return {
    __workletContextObject: true,
    current: {
      emitters: new Float32Array(20),
      glyphIndices: new Uint8Array(cellCount),
      variantIndices: new Uint8Array(cellCount),
    },
  };
}

function createPalette(): readonly PaletteEntry[] {
  const entries: PaletteEntry[] = [];
  const brightnessDivisor = Math.max(1, CHARSET.length - 1);

  for (const fontStyle of STYLES) {
    for (const fontWeight of WEIGHTS) {
      const weightFactor = fontWeight === '300' ? 0.86 : fontWeight === '500' ? 1.0 : 1.16;
      const styleFactor = fontStyle === 'italic' ? 1.04 : 1.0;

      for (let index = 0; index < CHARSET.length; index += 1) {
        const char = CHARSET[index];
        if (!char || char === ' ') continue;

        const width = measureTextWidth(char, {
          ...FIELD_STYLE,
          fontStyle,
          fontWeight,
        });

        if (width <= 0) continue;

        entries.push({
          brightness: clampNumber((index / brightnessDivisor) * weightFactor * styleFactor, 0, 1),
          char,
          fontStyle,
          fontWeight,
          width,
        });
      }
    }
  }

  entries.sort((left, right) => left.brightness - right.brightness);
  return entries;
}

function createLookup(targetCellWidth?: number): LookupTable {
  const cellWidth = targetCellWidth ?? 10;
  const glyphIndices = new Uint8Array(256);
  const variantIndices = new Uint8Array(256);

  for (let byte = 0; byte < 256; byte += 1) {
    const brightness = byte / 255;
    if (brightness < 0.035) {
      glyphIndices[byte] = 0;
      variantIndices[byte] = 0;
      continue;
    }

    const match = findBestGlyph(brightness, cellWidth);
    const band = resolveAlphaBand(brightness);
    const weightIndex = resolveWeightVariantIndex(match.fontWeight);
    const styleIndex = STYLES.indexOf(match.fontStyle);
    glyphIndices[byte] = CHARSET.indexOf(match.char);
    variantIndices[byte] = band * VARIANT_COUNT + styleIndex * WEIGHTS.length + weightIndex;
  }

  return { glyphIndices, variantIndices };
}

function findBestGlyph(targetBrightness: number, targetCellWidth: number): PaletteEntry {
  let best = palette[0];
  let bestScore = Number.POSITIVE_INFINITY;

  for (let index = 0; index < palette.length; index += 1) {
    const entry = palette[index];
    const brightnessError = Math.abs(entry.brightness - targetBrightness) * 2.35;
    const widthError = Math.abs(entry.width - targetCellWidth) / targetCellWidth;
    const score = brightnessError + widthError;

    if (score < bestScore) {
      best = entry;
      bestScore = score;
    }
  }

  return best;
}

function resolveWeightVariantIndex(fontWeight: string): number {
  'worklet';
  if (fontWeight === '300') return 0;
  if (fontWeight === '500') return 1;
  return 2;
}

function resolveAlphaBand(brightness: number): number {
  'worklet';
  if (brightness < 0.22) return 0;
  if (brightness < 0.44) return 1;
  if (brightness < 0.68) return 2;
  return 3;
}

function populateEmitters(width: number, height: number, phase: number, pointer: TextFieldPointer, emitters: Float32Array): number {
  'worklet';
  const minSize = Math.min(width, height);
  const centerX = width / 2;
  const centerY = height / 2;

  const setEmitter = (index: number, x: number, y: number, r: number, opacity: number) => {
    const offset = index * 4;
    emitters[offset] = x;
    emitters[offset + 1] = y;
    emitters[offset + 2] = r;
    emitters[offset + 3] = opacity;
  };

  setEmitter(
    0,
    centerX + Math.cos(phase * 0.72) * minSize * 0.18 + Math.sin(phase * 0.18) * minSize * 0.05,
    centerY - minSize * 0.1 + Math.sin(phase * 0.88) * minSize * 0.22,
    minSize * 0.16,
    0.94
  );
  setEmitter(
    1,
    centerX - minSize * 0.2 + Math.cos(phase * 0.62 + 1.6) * minSize * 0.17,
    centerY + Math.sin(phase * 0.52 + 0.7) * minSize * 0.19,
    minSize * 0.11,
    0.72
  );
  setEmitter(
    2,
    centerX + minSize * 0.21 + Math.cos(phase * 0.91 + 2.4) * minSize * 0.16,
    centerY + Math.sin(phase * 0.77 + 2.1) * minSize * 0.17,
    minSize * 0.1,
    0.68
  );
  setEmitter(3, centerX + Math.sin(phase * 1.4) * minSize * 0.12, centerY + Math.cos(phase * 1.18) * minSize * 0.11, minSize * 0.07, 0.54);

  if (!pointer.active) return 4;

  setEmitter(4, pointer.x, pointer.y, minSize * 0.13, 1.18);
  return 5;
}

function ensureFrameBuffer(frameBuffer: TextFieldFrameBuffer, cellCount: number): Uint8Array {
  'worklet';

  const current = frameBuffer.current.glyphIndices;
  if (current.length === cellCount) return current;

  const next = new Uint8Array(cellCount);
  frameBuffer.current = {
    emitters: frameBuffer.current.emitters,
    glyphIndices: next,
    variantIndices: new Uint8Array(cellCount),
  };
  return next;
}

export function stepTextFieldRuntime(
  input: TextFieldRuntimeInput,
  frameBuffer: TextFieldFrameBuffer,
  phase: number,
  pointer: TextFieldPointer
): TextFieldFrame {
  'worklet';

  const emitters = frameBuffer.current.emitters;
  const emitterCount = populateEmitters(input.width, input.height, phase, pointer, emitters);
  const glyphIndices = ensureFrameBuffer(frameBuffer, input.cellCount);
  const variantIndices = frameBuffer.current.variantIndices;
  const horizontalPhaseSin = Math.sin(phase * 0.8);
  const horizontalPhaseCos = Math.cos(phase * 0.8);
  const verticalPhaseSin = Math.sin(-phase * 0.66);
  const verticalPhaseCos = Math.cos(-phase * 0.66);
  const diagonalPhaseSin = Math.sin(phase * 1.1);
  const diagonalPhaseCos = Math.cos(phase * 1.1);
  const horizontalWaveSinFactor = horizontalPhaseSin * 0.028;
  const horizontalWaveCosFactor = horizontalPhaseCos * 0.028;
  const verticalWaveSinFactor = verticalPhaseSin * 0.023;
  const verticalWaveCosFactor = verticalPhaseCos * 0.023;
  const diagonalWaveSinFactor = diagonalPhaseSin * 0.018;
  const diagonalWaveCosFactor = diagonalPhaseCos * 0.018;
  for (let cellIndex = 0; cellIndex < input.cellCount; cellIndex += 1) {
    let brightness =
      input.cellAmbientBrightness[cellIndex] +
      input.cellHorizontalWaveSin[cellIndex] * horizontalWaveCosFactor +
      input.cellHorizontalWaveCos[cellIndex] * horizontalWaveSinFactor +
      input.cellVerticalWaveSin[cellIndex] * verticalWaveCosFactor +
      input.cellVerticalWaveCos[cellIndex] * verticalWaveSinFactor +
      input.cellDiagonalWaveSin[cellIndex] * diagonalWaveCosFactor +
      input.cellDiagonalWaveCos[cellIndex] * diagonalWaveSinFactor;

    const x = input.cellXs[cellIndex];
    const y = input.cellYs[cellIndex];
    for (let emitterIndex = 0; emitterIndex < emitterCount; emitterIndex += 1) {
      const offset = emitterIndex * 4;
      const dx = x - emitters[offset];
      const dy = y - emitters[offset + 1];
      const distance2 = dx * dx + dy * dy;
      const radius2 = emitters[offset + 2] * emitters[offset + 2];
      brightness += Math.exp(-distance2 / radius2) * emitters[offset + 3];
    }

    const lookupIndex = clampInt(brightness * 255, 0, 255);
    glyphIndices[cellIndex] = input.lookupGlyphIndices[lookupIndex] ?? 0;
    variantIndices[cellIndex] = input.lookupVariantIndices[lookupIndex] ?? 0;
  }

  return { glyphIndices, variantIndices };
}
