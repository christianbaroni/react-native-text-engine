import { measureTextWidth, type TextMeasureStyle } from 'react-native-text-engine';
import { IS_IOS } from '../constants';

type WorkletContextValue<T> = {
  __workletContextObject: true;
  current: T;
};

type PaletteEntry = {
  brightness: number;
  char: string;
  fontWeight: string;
  width: number;
};

type HeatStamp = {
  radiusX: number;
  radiusY: number;
  sizeX: number;
  sizeY: number;
  values: Float32Array;
};

type FrameState = {
  glyphIndices: Uint8Array;
  heat: Float32Array;
  initialized: number;
  nextHeat: Float32Array;
  phase: number;
  randomState: number;
  sparks: Float32Array;
  variantIndices: Uint8Array;
};

export type FireConfig = {
  artHeight: number;
  artWidth: number;
  cols: number;
  rows: number;
};

export type FireControls = {
  bodyBias: number;
  wind: number;
};

export const DEFAULT_FIRE_CONTROLS: FireControls = {
  bodyBias: 0,
  wind: 0,
};

export type FireRuntimeInput = FireConfig & {
  cellAmbient: Float32Array;
  cellCount: number;
  cellFuel: Float32Array;
  cellPhase: Float32Array;
  emberStamp: HeatStamp;
  fieldCols: number;
  fieldRows: number;
  fieldScaleX: number;
  fieldScaleY: number;
  fuelMask: Float32Array;
  lookupGlyphIndices: Uint8Array;
  lookupVariantIndices: Uint8Array;
  sampleIndexA: Int32Array;
  sampleIndexB: Int32Array;
  sampleIndexC: Int32Array;
  sampleIndexD: Int32Array;
  sparkStamp: HeatStamp;
  touchStamp: HeatStamp;
};

export type FireFrame = {
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
};

export type FireFrameBuffer = WorkletContextValue<FrameState>;

const FONT_FAMILY = IS_IOS ? 'Menlo' : 'monospace';
const FONT_SIZE = 11;
const LINE_HEIGHT = 12;
const FIELD_OVERSAMPLE = 2;
const SPARK_COUNT = 64;
const CHARSET = " .`',:^~i!lI?/)(tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*+=#%@";
const WEIGHTS = ['400', '700'] as const;

const TONE_COLORS = [
  'rgba(28, 7, 3, 0.08)',
  'rgba(58, 12, 4, 0.16)',
  'rgba(96, 22, 6, 0.26)',
  'rgba(148, 38, 10, 0.38)',
  'rgba(206, 70, 16, 0.56)',
  'rgba(242, 118, 28, 0.76)',
  'rgba(255, 184, 72, 0.92)',
  'rgba(255, 238, 188, 1)',
] as const;

export const FIRE_STYLE: TextMeasureStyle = {
  color: '#ffefcf',
  fontFamily: FONT_FAMILY,
  fontSize: FONT_SIZE,
  fontWeight: '400',
  letterSpacing: 0,
  lineHeight: LINE_HEIGHT,
};

export const FIRE_VARIANTS = TONE_COLORS.flatMap((color, toneIndex) =>
  WEIGHTS.map(fontWeight => ({
    color,
    fontWeight,
    key: `${toneIndex}-${fontWeight}`,
  }))
);

export const FIRE_GLYPH_PALETTE = CHARSET;

function clampScalar(value: number, min: number, max: number): number {
  'worklet';
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

function smoothstepScalar(edge0: number, edge1: number, value: number): number {
  'worklet';
  const x = clampScalar((value - edge0) / (edge1 - edge0), 0, 1);
  return x * x * (3 - 2 * x);
}

function clampNumber(value: number, min: number, max: number): number {
  'worklet';
  return clampScalar(value, min, max);
}

function clampInt(value: number, min: number, max: number): number {
  'worklet';
  return Math.round(clampNumber(value, min, max));
}

function createPalette(): readonly PaletteEntry[] {
  const entries: PaletteEntry[] = [];
  const brightnessDivisor = Math.max(1, CHARSET.length - 1);

  for (const fontWeight of WEIGHTS) {
    const weightFactor = fontWeight === '700' ? 1.14 : 0.92;

    for (let index = 0; index < CHARSET.length; index += 1) {
      const char = CHARSET[index];
      if (!char || char === ' ') continue;

      const width = measureTextWidth(char, {
        ...FIRE_STYLE,
        fontWeight,
      });
      if (width <= 0) continue;

      entries.push({
        brightness: clampScalar((index / brightnessDivisor) * weightFactor, 0, 1),
        char,
        fontWeight,
        width,
      });
    }
  }

  entries.sort((left, right) => left.brightness - right.brightness);
  return entries;
}

const palette = createPalette();

function findBestGlyph(targetBrightness: number, targetCellWidth: number): PaletteEntry {
  let best = palette[0];
  let bestScore = Number.POSITIVE_INFINITY;

  for (let index = 0; index < palette.length; index += 1) {
    const entry = palette[index];
    if (!entry) continue;

    const brightnessError = Math.abs(entry.brightness - targetBrightness) * 2.2;
    const widthError = Math.abs(entry.width - targetCellWidth) / targetCellWidth;
    const score = brightnessError + widthError;
    if (score < bestScore) {
      best = entry;
      bestScore = score;
    }
  }

  return best;
}

function resolveToneBand(brightness: number): number {
  if (brightness < 0.08) return 0;
  if (brightness < 0.16) return 1;
  if (brightness < 0.28) return 2;
  if (brightness < 0.42) return 3;
  if (brightness < 0.56) return 4;
  if (brightness < 0.72) return 5;
  if (brightness < 0.88) return 6;
  return 7;
}

function resolveWeightBand(brightness: number): number {
  return brightness < 0.62 ? 0 : 1;
}

function createLookup(targetCellWidth: number): {
  glyphIndices: Uint8Array;
  variantIndices: Uint8Array;
} {
  const glyphIndices = new Uint8Array(256);
  const variantIndices = new Uint8Array(256);

  for (let byte = 0; byte < 256; byte += 1) {
    const brightness = byte / 255;
    if (brightness < 0.025) {
      glyphIndices[byte] = 0;
      variantIndices[byte] = 0;
      continue;
    }

    const match = findBestGlyph(brightness, targetCellWidth);
    const toneIndex = resolveToneBand(brightness);
    const weightIndex = resolveWeightBand(brightness);
    glyphIndices[byte] = CHARSET.indexOf(match.char);
    variantIndices[byte] = toneIndex * WEIGHTS.length + weightIndex;
  }

  return { glyphIndices, variantIndices };
}

function createStamp(radiusPx: number, fieldScaleX: number, fieldScaleY: number): HeatStamp {
  const fieldRadiusX = radiusPx * fieldScaleX;
  const fieldRadiusY = radiusPx * fieldScaleY;
  const radiusX = Math.ceil(fieldRadiusX);
  const radiusY = Math.ceil(fieldRadiusY);
  const sizeX = radiusX * 2 + 1;
  const sizeY = radiusY * 2 + 1;
  const values = new Float32Array(sizeX * sizeY);

  for (let y = -radiusY; y <= radiusY; y += 1) {
    for (let x = -radiusX; x <= radiusX; x += 1) {
      const normalized = Math.sqrt((x / fieldRadiusX) ** 2 + (y / fieldRadiusY) ** 2);
      values[(y + radiusY) * sizeX + x + radiusX] = normalized >= 1 ? 0 : 1 - normalized;
    }
  }

  return { radiusX, radiusY, sizeX, sizeY, values };
}

function randomFloat(frameState: FrameState): number {
  'worklet';
  frameState.randomState = (frameState.randomState * 1664525 + 1013904223) >>> 0;
  return frameState.randomState / 4294967296;
}

function spawnSpark(frameState: FrameState, input: FireRuntimeInput, sparkIndex: number): void {
  'worklet';

  const offset = sparkIndex * 5;
  frameState.sparks[offset] = input.artWidth * 0.5 + (randomFloat(frameState) - 0.5) * input.artWidth * 0.16;
  frameState.sparks[offset + 1] = input.artHeight * (0.88 + randomFloat(frameState) * 0.08);
  frameState.sparks[offset + 2] = (randomFloat(frameState) - 0.5) * 0.18;
  frameState.sparks[offset + 3] = -(0.78 + randomFloat(frameState) * 0.72);
  frameState.sparks[offset + 4] = 0.32 + randomFloat(frameState) * 0.42;
}

function ensureFrameBuffer(frameBuffer: FireFrameBuffer, input: FireRuntimeInput): FrameState {
  'worklet';

  const current = frameBuffer.current;
  const fieldCellCount = input.fieldCols * input.fieldRows;
  if (current.glyphIndices.length === input.cellCount && current.heat.length === fieldCellCount) return current;

  const next = createFireFrameBuffer(input.cellCount, fieldCellCount).current;
  frameBuffer.current = next;
  return next;
}

function initializeFrameState(frameState: FrameState, input: FireRuntimeInput): void {
  'worklet';

  if (frameState.initialized === 1) return;
  frameState.initialized = 1;
  frameState.randomState = 1337;

  for (let sparkIndex = 0; sparkIndex < SPARK_COUNT; sparkIndex += 1) {
    spawnSpark(frameState, input, sparkIndex);
  }
}

function splatStamp(
  input: FireRuntimeInput,
  heat: Float32Array,
  centerX: number,
  centerY: number,
  stamp: HeatStamp,
  intensity: number
): void {
  'worklet';
  const gridCenterX = Math.round(centerX * input.fieldScaleX);
  const gridCenterY = Math.round(centerY * input.fieldScaleY);

  for (let y = -stamp.radiusY; y <= stamp.radiusY; y += 1) {
    const gridY = gridCenterY + y;
    if (gridY < 0 || gridY >= input.fieldRows) continue;

    const heatRowOffset = gridY * input.fieldCols;
    const stampRowOffset = (y + stamp.radiusY) * stamp.sizeX;

    for (let x = -stamp.radiusX; x <= stamp.radiusX; x += 1) {
      const gridX = gridCenterX + x;
      if (gridX < 0 || gridX >= input.fieldCols) continue;

      const alpha = stamp.values[stampRowOffset + x + stamp.radiusX];
      if (alpha <= 0) continue;

      const heatIndex = heatRowOffset + gridX;
      heat[heatIndex] = Math.min(1.24, heat[heatIndex] + alpha * intensity);
    }
  }
}

export function resolveFireConfig(width: number, height: number): FireConfig {
  const artWidth = Math.max(320, Math.min(width - 18, 392));
  const cols = clampScalar(Math.round(artWidth / 6.3), 48, 64);
  const rows = clampScalar(Math.floor((height - 128) / LINE_HEIGHT), 42, 52);

  return {
    artHeight: rows * LINE_HEIGHT,
    artWidth,
    cols,
    rows,
  };
}

export function createFireRuntimeInput(config: FireConfig): FireRuntimeInput {
  const fieldCols = config.cols * FIELD_OVERSAMPLE;
  const fieldRows = config.rows * FIELD_OVERSAMPLE;
  const fieldScaleX = fieldCols / config.artWidth;
  const fieldScaleY = fieldRows / config.artHeight;
  const cellCount = config.cols * config.rows;
  const lookup = createLookup(config.artWidth / config.cols);

  const cellAmbient = new Float32Array(cellCount);
  const cellFuel = new Float32Array(cellCount);
  const cellPhase = new Float32Array(cellCount);
  const sampleIndexA = new Int32Array(cellCount);
  const sampleIndexB = new Int32Array(cellCount);
  const sampleIndexC = new Int32Array(cellCount);
  const sampleIndexD = new Int32Array(cellCount);
  const fuelMask = new Float32Array(fieldCols * fieldRows);

  for (let fieldRow = 0; fieldRow < fieldRows; fieldRow += 1) {
    const y = fieldRow / Math.max(1, fieldRows - 1);
    const aboveBase = 1 - y;
    const width = 0.1 + 0.21 * (1 - Math.pow(aboveBase, 1.75));

    for (let fieldCol = 0; fieldCol < fieldCols; fieldCol += 1) {
      const x = fieldCol / Math.max(1, fieldCols - 1);
      const centerDistance = Math.abs(x - 0.5) / Math.max(0.08, width);
      const cone = 1 - smoothstepScalar(0.66, 1.04, centerDistance);
      const vertical = 1 - smoothstepScalar(0.56, 0.97, aboveBase);
      fuelMask[fieldRow * fieldCols + fieldCol] = cone * vertical;
    }
  }

  let cellIndex = 0;
  for (let rowIndex = 0; rowIndex < config.rows; rowIndex += 1) {
    const sampleTop = Math.floor((rowIndex + 0.2) * FIELD_OVERSAMPLE);
    const sampleBottom = Math.min(fieldRows - 1, Math.floor((rowIndex + 0.8) * FIELD_OVERSAMPLE));
    const y = rowIndex / Math.max(1, config.rows - 1);

    for (let colIndex = 0; colIndex < config.cols; colIndex += 1) {
      const sampleLeft = Math.floor((colIndex + 0.2) * FIELD_OVERSAMPLE);
      const sampleRight = Math.min(fieldCols - 1, Math.floor((colIndex + 0.8) * FIELD_OVERSAMPLE));
      const x = colIndex / Math.max(1, config.cols - 1);
      const emberBed = (1 - smoothstepScalar(0.16, 0.62, Math.abs(x - 0.5))) * smoothstepScalar(0.82, 1, y);

      sampleIndexA[cellIndex] = sampleTop * fieldCols + sampleLeft;
      sampleIndexB[cellIndex] = sampleTop * fieldCols + sampleRight;
      sampleIndexC[cellIndex] = sampleBottom * fieldCols + sampleLeft;
      sampleIndexD[cellIndex] = sampleBottom * fieldCols + sampleRight;
      cellAmbient[cellIndex] = emberBed * 0.2;
      cellFuel[cellIndex] =
        (fuelMask[sampleIndexA[cellIndex]] +
          fuelMask[sampleIndexB[cellIndex]] +
          fuelMask[sampleIndexC[cellIndex]] +
          fuelMask[sampleIndexD[cellIndex]]) *
        0.25;
      cellPhase[cellIndex] = (x * 14.2 + y * 6.1) * Math.PI;
      cellIndex += 1;
    }
  }

  return {
    ...config,
    cellAmbient,
    cellCount,
    cellFuel,
    cellPhase,
    emberStamp: createStamp(config.artWidth * 0.018, fieldScaleX, fieldScaleY),
    fieldCols,
    fieldRows,
    fieldScaleX,
    fieldScaleY,
    fuelMask,
    lookupGlyphIndices: lookup.glyphIndices,
    lookupVariantIndices: lookup.variantIndices,
    sampleIndexA,
    sampleIndexB,
    sampleIndexC,
    sampleIndexD,
    sparkStamp: createStamp(config.artWidth * 0.014, fieldScaleX, fieldScaleY),
    touchStamp: createStamp(config.artWidth * 0.06, fieldScaleX, fieldScaleY),
  };
}

export function createFireFrameBuffer(cellCount: number, fieldCellCount: number): FireFrameBuffer {
  'worklet';

  return {
    __workletContextObject: true,
    current: {
      glyphIndices: new Uint8Array(cellCount),
      heat: new Float32Array(fieldCellCount),
      initialized: 0,
      nextHeat: new Float32Array(fieldCellCount),
      phase: 0,
      randomState: 1337,
      sparks: new Float32Array(SPARK_COUNT * 5),
      variantIndices: new Uint8Array(cellCount),
    },
  };
}

export function stepFireRuntime(input: FireRuntimeInput, frameBuffer: FireFrameBuffer, phase: number, controls: FireControls): FireFrame {
  'worklet';

  const frameState = ensureFrameBuffer(frameBuffer, input);
  initializeFrameState(frameState, input);

  const wind = controls.wind;
  const windAbs = Math.abs(wind);
  const effectiveBodyBias = clampNumber(controls.bodyBias * (1 - windAbs * 0.16), -0.6, 0.6);
  const windScatter = clampNumber(Math.abs(wind) * 0.34, 0, 0.68);
  const heat = frameState.heat;
  const nextHeat = frameState.nextHeat;
  nextHeat.fill(0);

  const baseDepth = clampInt(5 + effectiveBodyBias * 1.4, 4, 6);
  const baseStartRow = input.fieldRows - baseDepth;
  const baseSeedBase = 0.68 + effectiveBodyBias * 0.06;
  const baseSeedStep = 0.055 + effectiveBodyBias * 0.012;
  const coolingBase = 0.014 - effectiveBodyBias * 0.003;
  const coolingRise = 0.032 - effectiveBodyBias * 0.006;
  const retentionBase = 0.974 + effectiveBodyBias * 0.012;

  for (let rowIndex = baseStartRow; rowIndex < input.fieldRows; rowIndex += 1) {
    const rowOffset = rowIndex * input.fieldCols;
    const seedStrength = baseSeedBase + (rowIndex - baseStartRow) * baseSeedStep;
    const aboveBase = 1 - rowIndex / Math.max(1, input.fieldRows - 1);

    for (let colIndex = 0; colIndex < input.fieldCols; colIndex += 1) {
      const mask = input.fuelMask[rowOffset + colIndex];
      if (mask <= 0) continue;
      const baseCore = smoothstepScalar(0.22, 0.9, mask);

      const flicker =
        0.86 +
        Math.sin(phase * 10.8 + colIndex * 0.18) * 0.1 +
        Math.cos(phase * 7.2 + colIndex * 0.07) * 0.06 +
        randomFloat(frameState) * 0.08;
      const scatterSeed = 1 - windScatter * baseCore * (0.03 + aboveBase * 0.08);
      nextHeat[rowOffset + colIndex] = clampNumber(mask * seedStrength * flicker * scatterSeed, 0, 1.24);
    }
  }

  for (let rowIndex = input.fieldRows - 2; rowIndex >= 0; rowIndex -= 1) {
    const aboveBase = 1 - rowIndex / Math.max(1, input.fieldRows - 1);
    const rowOffset = rowIndex * input.fieldCols;
    const belowRowOffset = (rowIndex + 1) * input.fieldCols;
    const below2RowOffset = Math.min(input.fieldRows - 1, rowIndex + 2) * input.fieldCols;

    for (let colIndex = 0; colIndex < input.fieldCols; colIndex += 1) {
      const mask = input.fuelMask[rowOffset + colIndex];
      if (mask <= 0.002) continue;
      const windMix = windScatter * (0.18 + aboveBase * 0.82);

      const sway = Math.sin(phase * 1.1 + rowIndex * 0.08) * 0.5;
      const jitter = (randomFloat(frameState) - 0.5) * 1.6;
      const drift = clampInt(colIndex + sway + jitter - wind * (0.24 + aboveBase * 0.9), 0, input.fieldCols - 1);
      const left = Math.max(0, drift - 1);
      const right = Math.min(input.fieldCols - 1, drift + 1);
      const below = heat[belowRowOffset + drift];
      const belowLeft = heat[belowRowOffset + left];
      const belowRight = heat[belowRowOffset + right];
      const belowFar = heat[below2RowOffset + drift];
      const coreMask = smoothstepScalar(0.22, 0.88, mask) * smoothstepScalar(0.1, 0.76, aboveBase);
      const scatterLoss = windScatter * coreMask;
      const carryWeight = 0.46 - windMix * 0.08;
      const lateralWeight = 0.2 + windMix * 0.035;
      const farWeight = 0.14 + windMix * 0.01;

      let value = below * carryWeight + (belowLeft + belowRight) * lateralWeight + belowFar * farWeight;
      value -= coolingBase + aboveBase * coolingRise + windMix * 0.006 + randomFloat(frameState) * 0.018;
      value *= retentionBase + mask * 0.014 - windMix * 0.02;
      value -= scatterLoss * 0.022;
      value *= 1 - scatterLoss * 0.045;

      nextHeat[rowOffset + colIndex] = clampNumber(value, 0, 1.24) * mask;
    }
  }

  frameState.heat = nextHeat;
  frameState.nextHeat = heat;

  const currentHeat = frameState.heat;
  for (let sparkIndex = 0; sparkIndex < SPARK_COUNT; sparkIndex += 1) {
    const offset = sparkIndex * 5;
    let x = frameState.sparks[offset];
    let y = frameState.sparks[offset + 1];
    let vx = frameState.sparks[offset + 2];
    let vy = frameState.sparks[offset + 3];
    let intensity = frameState.sparks[offset + 4];

    const lift = clampNumber(1 - y / input.artHeight, 0, 1);
    vx += (input.artWidth * 0.5 - x) * 0.0007 + Math.sin(phase * 1.3 + sparkIndex * 0.73 + y * 0.04) * 0.018;
    vx += wind * (0.01 + lift * 0.016);
    vy -= 0.012 + lift * 0.016;
    vx *= 0.984;
    vy *= 0.988;
    x += vx;
    y += vy;
    intensity *= 0.992;

    const shouldRespawn = y < input.artHeight * 0.08 || x < -input.artWidth * 0.1 || x > input.artWidth * 1.1 || intensity < 0.08;
    if (shouldRespawn) {
      spawnSpark(frameState, input, sparkIndex);
      continue;
    }

    frameState.sparks[offset] = x;
    frameState.sparks[offset + 1] = y;
    frameState.sparks[offset + 2] = vx;
    frameState.sparks[offset + 3] = vy;
    frameState.sparks[offset + 4] = intensity;
    splatStamp(input, currentHeat, x, y, input.sparkStamp, intensity);
  }

  for (let cellIndex = 0; cellIndex < input.cellCount; cellIndex += 1) {
    const sampledHeat =
      (currentHeat[input.sampleIndexA[cellIndex]] +
        currentHeat[input.sampleIndexB[cellIndex]] +
        currentHeat[input.sampleIndexC[cellIndex]] +
        currentHeat[input.sampleIndexD[cellIndex]]) *
      0.25;

    const brightness =
      sampledHeat * (0.22 + input.cellFuel[cellIndex] * 0.96) +
      input.cellAmbient[cellIndex] +
      Math.sin(phase * 4.4 + input.cellPhase[cellIndex]) * sampledHeat * 0.04;
    const lookupIndex = clampInt(Math.pow(clampNumber(brightness * 1.28, 0, 1.18), 0.88) * 255, 0, 255);
    frameState.glyphIndices[cellIndex] = input.lookupGlyphIndices[lookupIndex] ?? 0;
    frameState.variantIndices[cellIndex] = input.lookupVariantIndices[lookupIndex] ?? 0;
  }

  return {
    glyphIndices: frameState.glyphIndices,
    variantIndices: frameState.variantIndices,
  };
}
