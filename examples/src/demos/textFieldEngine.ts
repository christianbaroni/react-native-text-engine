import { Platform } from 'react-native';
import { measureTextWidth, type TextMeasureStyle } from 'react-native-text-engine';

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
  cols: number;
  lookup: readonly LookupEntry[];
  height: number;
  rows: number;
  sampleXs: readonly number[];
  sampleYs: readonly number[];
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
  glyphs: string;
  variantIndices: Uint8Array;
};

export type TextFieldFrameBuffer = WorkletContextValue<{
  variantIndices: Uint8Array;
}>;

type Emitter = {
  opacity: number;
  r: number;
  x: number;
  y: number;
};

type PaletteEntry = {
  brightness: number;
  char: string;
  fontStyle: FontStyleVariant;
  fontWeight: string;
  width: number;
};

type LookupEntry = {
  char: string;
  variantIndex: number;
};

const FONT_FAMILY = Platform.OS === 'ios' ? 'Georgia' : 'serif';
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
  const cellWidth = config.artWidth / config.cols;
  const cellHeight = config.artHeight / config.rows;
  const sampleXs = new Array<number>(config.cols);
  const sampleYs = new Array<number>(config.rows);

  for (let index = 0; index < config.cols; index += 1) {
    sampleXs[index] = (index + 0.5) * cellWidth;
  }

  for (let index = 0; index < config.rows; index += 1) {
    sampleYs[index] = (index + 0.5) * cellHeight;
  }

  return {
    cols: config.cols,
    height: config.artHeight,
    lookup: createLookup(cellWidth),
    rows: config.rows,
    sampleXs,
    sampleYs,
    width: config.artWidth,
  };
}

export function createTextFieldFrameBuffer(cellCount: number): TextFieldFrameBuffer {
  return {
    __workletContextObject: true,
    current: {
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

function createLookup(targetCellWidth?: number): readonly LookupEntry[] {
  const cellWidth = targetCellWidth ?? 10;
  const values = new Array<LookupEntry>(256);

  for (let byte = 0; byte < 256; byte += 1) {
    const brightness = byte / 255;
    if (brightness < 0.035) {
      values[byte] = {
        char: ' ',
        variantIndex: 0,
      };
      continue;
    }

    const match = findBestGlyph(brightness, cellWidth);
    const band = resolveAlphaBand(brightness);
    const weightIndex = resolveWeightVariantIndex(match.fontWeight);
    const styleIndex = STYLES.indexOf(match.fontStyle);
    const variantIndex = styleIndex * WEIGHTS.length + weightIndex;
    values[byte] = {
      char: match.char,
      variantIndex: band * VARIANT_COUNT + variantIndex,
    };
  }

  return values;
}

function findBestGlyph(targetBrightness: number, targetCellWidth: number): PaletteEntry {
  let best = palette[0]!;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let index = 0; index < palette.length; index += 1) {
    const entry = palette[index]!;
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

function createEmitters(width: number, height: number, phase: number, pointer: TextFieldPointer): readonly Emitter[] {
  'worklet';

  const minSize = Math.min(width, height);
  const centerX = width / 2;
  const centerY = height / 2;
  const emitters: Emitter[] = [
    {
      opacity: 0.94,
      r: minSize * 0.16,
      x: centerX + Math.cos(phase * 0.72) * minSize * 0.18 + Math.sin(phase * 0.18) * minSize * 0.05,
      y: centerY - minSize * 0.1 + Math.sin(phase * 0.88) * minSize * 0.22,
    },
    {
      opacity: 0.72,
      r: minSize * 0.11,
      x: centerX - minSize * 0.2 + Math.cos(phase * 0.62 + 1.6) * minSize * 0.17,
      y: centerY + Math.sin(phase * 0.52 + 0.7) * minSize * 0.19,
    },
    {
      opacity: 0.68,
      r: minSize * 0.1,
      x: centerX + minSize * 0.21 + Math.cos(phase * 0.91 + 2.4) * minSize * 0.16,
      y: centerY + Math.sin(phase * 0.77 + 2.1) * minSize * 0.17,
    },
    {
      opacity: 0.54,
      r: minSize * 0.07,
      x: centerX + Math.sin(phase * 1.4) * minSize * 0.12,
      y: centerY + Math.cos(phase * 1.18) * minSize * 0.11,
    },
  ];

  if (pointer.active) {
    emitters.push({
      opacity: 1.18,
      r: minSize * 0.13,
      x: pointer.x,
      y: pointer.y,
    });
  }

  return emitters;
}

function sampleBrightness(x: number, y: number, width: number, height: number, emitters: readonly Emitter[], phase: number): number {
  'worklet';

  const normalizedX = (x - width / 2) / width;
  const normalizedY = (y - height / 2) / height;
  const vignette = 1 - smoothstep(0.1, 0.68, Math.hypot(normalizedX * 1.02, normalizedY * 1.28));
  let brightness = vignette * 0.06;

  for (let index = 0; index < emitters.length; index += 1) {
    const emitter = emitters[index];
    if (emitter === undefined) continue;

    const dx = x - emitter.x;
    const dy = y - emitter.y;
    const distance2 = dx * dx + dy * dy;
    const radius2 = emitter.r * emitter.r;
    brightness += Math.exp(-distance2 / radius2) * emitter.opacity;
  }

  const wave =
    Math.sin(normalizedX * 10.5 + phase * 0.8) * 0.028 +
    Math.sin(normalizedY * 14.5 - phase * 0.66) * 0.023 +
    Math.sin((normalizedX + normalizedY) * 18.0 + phase * 1.1) * 0.018;

  return clampNumber(brightness + wave, 0, 1);
}

function ensureFrameBuffer(frameBuffer: TextFieldFrameBuffer, cellCount: number): Uint8Array {
  'worklet';

  const current = frameBuffer.current.variantIndices;
  if (current.length === cellCount) return current;

  const next = new Uint8Array(cellCount);
  frameBuffer.current = { variantIndices: next };
  return next;
}

export function stepTextFieldRuntime(
  input: TextFieldRuntimeInput,
  frameBuffer: TextFieldFrameBuffer,
  phase: number,
  pointer: TextFieldPointer
): TextFieldFrame {
  'worklet';

  const emitters = createEmitters(input.width, input.height, phase, pointer);
  const variantIndices = ensureFrameBuffer(frameBuffer, input.rows * input.cols);
  let cellIndex = 0;
  let glyphs = '';

  for (let rowIndex = 0; rowIndex < input.rows; rowIndex += 1) {
    const y = input.sampleYs[rowIndex] ?? 0;

    for (let colIndex = 0; colIndex < input.cols; colIndex += 1) {
      const x = input.sampleXs[colIndex] ?? 0;
      const brightness = sampleBrightness(x, y, input.width, input.height, emitters, phase);
      const lookupIndex = clampInt(brightness * 255, 0, 255);
      const entry = input.lookup[lookupIndex]!;
      glyphs += entry.char;
      variantIndices[cellIndex] = entry.variantIndex;
      cellIndex += 1;
    }
  }

  return { glyphs, variantIndices };
}
