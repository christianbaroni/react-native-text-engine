import { Platform } from 'react-native';
import { measureWidth, type TextMeasureRun, type TextMeasureStyle } from 'react-native-pretext';

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

export type TextFieldFrame = {
  text: string;
  runs: readonly TextMeasureRun[];
};

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
  color: string | null;
  fontStyle: FontStyleVariant;
  fontWeight: string;
};

const FONT_FAMILY = Platform.OS === 'ios' ? 'Georgia' : 'serif';
const CHARSET = ' .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const WEIGHTS = ['300', '500', '800'] as const;
const STYLES = ['normal', 'italic'] as const;
const AMBIENT_DIM_COLOR = '#F0C785';
const BRIGHTNESS_COLORS = ['#8B6841', '#B58349', '#DDA261', '#F0C785', '#FFF1CA'] as const;

export const FIELD_STYLE: TextMeasureStyle = {
  color: AMBIENT_DIM_COLOR,
  fontFamily: FONT_FAMILY,
  fontSize: 18,
  fontWeight: '300',
  letterSpacing: 0.04,
  lineHeight: 20,
};

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

        const width = measureWidth(char, {
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
        color: null,
        fontStyle: 'normal',
        fontWeight: FIELD_STYLE.fontWeight ?? '300',
      };
      continue;
    }

    const match = findBestGlyph(brightness, cellWidth);
    const band = resolveBrightnessBand(brightness);
    values[byte] = {
      char: match.char,
      color: BRIGHTNESS_COLORS[band] ?? BRIGHTNESS_COLORS[BRIGHTNESS_COLORS.length - 1],
      fontStyle: match.fontStyle,
      fontWeight: match.fontWeight,
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

function resolveBrightnessBand(brightness: number): number {
  'worklet';
  if (brightness < 0.18) return 0;
  if (brightness < 0.34) return 1;
  if (brightness < 0.52) return 2;
  if (brightness < 0.72) return 3;
  return 4;
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

export function stepTextFieldRuntime(input: TextFieldRuntimeInput, phase: number, pointer: TextFieldPointer): TextFieldFrame {
  'worklet';

  const emitters = createEmitters(input.width, input.height, phase, pointer);
  const chars = new Array<string>(input.rows * (input.cols + 1));
  const runs: TextMeasureRun[] = [];
  let charIndex = 0;
  let runStart = -1;
  let runColor = '';
  let runWeight = '';
  let runFontStyle: FontStyleVariant = 'normal';
  const baseFontWeight = FIELD_STYLE.fontWeight ?? '300';

  const flushRun = (end: number) => {
    'worklet';
    if (runStart < 0 || end <= runStart) return;

    const usesOverride = runColor !== AMBIENT_DIM_COLOR || runWeight !== baseFontWeight || runFontStyle !== 'normal';
    if (usesOverride) {
      const style: TextMeasureRun['style'] = {};
      if (runColor !== AMBIENT_DIM_COLOR) style.color = runColor;
      if (runWeight !== baseFontWeight) style.fontWeight = runWeight;
      if (runFontStyle !== 'normal') style.fontStyle = runFontStyle;
      runs.push({ end, start: runStart, style });
    }
    runStart = -1;
  };

  for (let rowIndex = 0; rowIndex < input.rows; rowIndex += 1) {
    const y = input.sampleYs[rowIndex] ?? 0;

    for (let colIndex = 0; colIndex < input.cols; colIndex += 1) {
      const x = input.sampleXs[colIndex] ?? 0;
      const brightness = sampleBrightness(x, y, input.width, input.height, emitters, phase);
      const lookupIndex = clampInt(brightness * 255, 0, 255);
      const entry = input.lookup[lookupIndex]!;

      chars[charIndex] = entry.char;

      const hasAccent = entry.color != null && entry.char !== ' ';
      const nextColor = hasAccent ? entry.color! : AMBIENT_DIM_COLOR;
      const nextWeight = hasAccent ? entry.fontWeight : baseFontWeight;
      const nextFontStyle = hasAccent ? entry.fontStyle : 'normal';

      if (!hasAccent) {
        flushRun(charIndex);
      } else if (runStart < 0) {
        runStart = charIndex;
        runColor = nextColor;
        runWeight = nextWeight;
        runFontStyle = nextFontStyle;
      } else if (nextColor !== runColor || nextWeight !== runWeight || nextFontStyle !== runFontStyle) {
        flushRun(charIndex);
        runStart = charIndex;
        runColor = nextColor;
        runWeight = nextWeight;
        runFontStyle = nextFontStyle;
      }

      charIndex += 1;
    }

    flushRun(charIndex);
    if (rowIndex < input.rows - 1) {
      chars[charIndex] = '\n';
      charIndex += 1;
    }
  }

  return {
    runs,
    text: chars.slice(0, charIndex).join(''),
  };
}
