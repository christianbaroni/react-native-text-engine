import { Platform } from 'react-native';
import { measureWidth, type TextMeasureStyle } from 'react-native-pretext';

export type TextFieldConfig = {
  artHeight: number;
  artWidth: number;
  cols: number;
  rows: number;
};

export type TextFieldEmitter = {
  opacity: number;
  r: number;
  x: number;
  y: number;
};

export type TextFieldRuntimeInput = {
  cols: number;
  emitters: TextFieldEmitter[];
  lookup: string[];
  rows: number;
  sampleXs: number[];
  sampleYs: number[];
  width: number;
  height: number;
};

const CHARSET = ' .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

const FONT_FAMILY = Platform.OS === 'ios' ? 'Georgia' : undefined;

export const FIELD_STYLE: TextMeasureStyle = {
  fontFamily: FONT_FAMILY,
  fontSize: 14,
  fontWeight: '500',
  letterSpacing: 0.1,
  lineHeight: 16,
};

type Glyph = {
  brightness: number;
  char: string;
  width: number;
};

export function resolveTextFieldConfig(width: number): TextFieldConfig {
  const artWidth = Math.min(Math.max(280, width - 68), 360);
  const cols = artWidth < 320 ? 30 : 34;
  const rows = artWidth < 320 ? 22 : 24;
  const lineHeight = FIELD_STYLE.lineHeight ?? 16;

  return {
    artHeight: rows * lineHeight,
    artWidth,
    cols,
    rows,
  };
}

function createEmitters(width: number, height: number, phase: number): TextFieldEmitter[] {
  'worklet';

  const minSize = Math.min(width, height);
  const centerX = width / 2;
  const centerY = height / 2;

  return [
    {
      opacity: 0.84,
      r: minSize * 0.22,
      x: centerX + Math.cos(phase * 0.84) * minSize * 0.18 + Math.sin(phase * 0.26) * minSize * 0.04,
      y: centerY - minSize * 0.1 + Math.sin(phase * 0.94) * minSize * 0.16,
    },
    {
      opacity: 0.78,
      r: minSize * 0.19,
      x: centerX - minSize * 0.16 + Math.cos(phase * 0.66 + 1.3) * minSize * 0.15,
      y: centerY + Math.sin(phase * 0.6 + 0.8) * minSize * 0.14,
    },
    {
      opacity: 0.72,
      r: minSize * 0.17,
      x: centerX + minSize * 0.16 + Math.cos(phase * 0.74 + 3.1) * minSize * 0.16,
      y: centerY + minSize * 0.02 + Math.sin(phase * 0.81 + 2.2) * minSize * 0.18,
    },
    {
      opacity: 0.5,
      r: minSize * 0.1,
      x: centerX + Math.sin(phase * 1.52) * minSize * 0.11,
      y: centerY + Math.cos(phase * 1.33) * minSize * 0.09,
    },
  ];
}

export function createTextFieldRuntimeInput(config: TextFieldConfig): TextFieldRuntimeInput {
  const cellWidth = config.artWidth / config.cols;
  const cellHeight = config.artHeight / config.rows;
  const lookup = createLookup(cellWidth);
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
    emitters: createEmitters(config.artWidth, config.artHeight, 0),
    height: config.artHeight,
    lookup,
    rows: config.rows,
    sampleXs,
    sampleYs,
    width: config.artWidth,
  };
}

function clampNumber(value: number, min: number, max: number): number {
  'worklet';
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function clampInt(value: number, min: number, max: number): number {
  'worklet';
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function smoothstep(edge0: number, edge1: number, value: number): number {
  'worklet';
  const x = clampNumber((value - edge0) / (edge1 - edge0), 0, 1);
  return x * x * (3 - 2 * x);
}

function sampleBrightness(x: number, y: number, width: number, height: number, emitters: readonly TextFieldEmitter[]): number {
  'worklet';

  const normalizedX = (x - width / 2) / width;
  const normalizedY = (y - height / 2) / height;
  const edgeFade = 1 - smoothstep(0.16, 0.56, Math.hypot(normalizedX * 1.08, normalizedY * 1.3));
  let brightness = edgeFade * 0.08;

  for (let index = 0; index < emitters.length; index += 1) {
    const emitter = emitters[index];
    if (emitter === undefined) continue;

    const dx = x - emitter.x;
    const dy = y - emitter.y;
    const distance2 = dx * dx + dy * dy;
    const radius2 = emitter.r * emitter.r;
    const influence = Math.exp(-distance2 / radius2);
    brightness += influence * emitter.opacity;
  }

  const ripple = Math.sin(normalizedX * 13 + normalizedY * 8) * 0.035 + Math.sin(normalizedY * 17 - normalizedX * 6) * 0.025;

  return clampNumber(brightness + ripple, 0, 1);
}

export function stepTextFieldRuntime(
  input: TextFieldRuntimeInput,
  phase: number
): {
  emitters: TextFieldEmitter[];
  text: string;
} {
  'worklet';

  const emitters = createEmitters(input.width, input.height, phase);
  const lineCount = input.rows;
  let text = '';

  for (let rowIndex = 0; rowIndex < lineCount; rowIndex += 1) {
    const y = input.sampleYs[rowIndex] ?? 0;

    for (let colIndex = 0; colIndex < input.cols; colIndex += 1) {
      const x = input.sampleXs[colIndex] ?? 0;
      const brightness = sampleBrightness(x, y, input.width, input.height, emitters);
      const lookupIndex = clampInt(Math.round(brightness * 255), 0, 255);
      text += input.lookup[lookupIndex] ?? ' ';
    }

    if (rowIndex < lineCount - 1) text += '\n';
  }

  return { emitters, text };
}

function createLookup(cellWidth: number): string[] {
  const glyphs = createGlyphs();
  const lookup = new Array<string>(256);

  for (let byte = 0; byte < 256; byte += 1) {
    const brightness = byte / 255;
    lookup[byte] = pickGlyph(glyphs, brightness, cellWidth);
  }

  return lookup;
}

function createGlyphs(): Glyph[] {
  const glyphs: Glyph[] = [];
  const count = CHARSET.length - 1;

  for (let index = 0; index < CHARSET.length; index += 1) {
    const char = CHARSET[index];
    if (char === undefined) continue;

    const width = measureWidth(char, FIELD_STYLE);
    if (width <= 0) continue;

    glyphs.push({
      brightness: count === 0 ? 0 : index / count,
      char,
      width,
    });
  }

  return glyphs;
}

function pickGlyph(glyphs: readonly Glyph[], brightness: number, targetWidth: number): string {
  let bestChar = ' ';
  let bestScore = Number.POSITIVE_INFINITY;

  for (let index = 0; index < glyphs.length; index += 1) {
    const glyph = glyphs[index];
    if (glyph === undefined) continue;

    const brightnessError = Math.abs(glyph.brightness - brightness) * 2.6;
    const widthError = Math.abs(glyph.width - targetWidth) / targetWidth;
    const score = brightnessError + widthError;

    if (score < bestScore) {
      bestScore = score;
      bestChar = glyph.char;
    }
  }

  return bestChar;
}
