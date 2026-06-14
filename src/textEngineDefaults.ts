import textEngineAppDefaults from './generated/TextEngineAppDefaults';
import type { GlyphFieldConfig, LayoutOptions, TextMeasureStyle } from './types';

const defaultAllowFontScaling = textEngineAppDefaults.allowFontScaling;
const defaultAnchorToCapHeight = textEngineAppDefaults.anchorToCapHeight;
const defaultColor = textEngineAppDefaults.color;
const defaultFontFamily = textEngineAppDefaults.fontFamily;
const defaultFontSize = textEngineAppDefaults.fontSize;
const defaultFontStyle = textEngineAppDefaults.fontStyle;
const defaultFontWeight = textEngineAppDefaults.fontWeight;
const defaultIncludeFontPadding = textEngineAppDefaults.includeFontPadding;
const defaultLetterSpacing = textEngineAppDefaults.letterSpacing;
const defaultLineHeight = textEngineAppDefaults.lineHeight;
const defaultTabularNumbers = textEngineAppDefaults.tabularNumbers;
const defaultTextBreakStrategy = textEngineAppDefaults.textBreakStrategy;

const hasTextMeasureDefaults =
  defaultAllowFontScaling !== undefined ||
  defaultColor !== undefined ||
  defaultFontFamily !== undefined ||
  defaultFontSize !== undefined ||
  defaultFontStyle !== undefined ||
  defaultFontWeight !== undefined ||
  defaultIncludeFontPadding !== undefined ||
  defaultLetterSpacing !== undefined ||
  defaultLineHeight !== undefined ||
  defaultTabularNumbers !== undefined ||
  defaultTextBreakStrategy !== undefined;

const textMeasureDefaults: TextMeasureStyle | undefined = !hasTextMeasureDefaults
  ? undefined
  : {
      allowFontScaling: defaultAllowFontScaling,
      color: defaultColor,
      fontFamily: defaultFontFamily,
      fontSize: defaultFontSize,
      fontStyle: defaultFontStyle,
      fontWeight: defaultFontWeight,
      includeFontPadding: defaultIncludeFontPadding,
      letterSpacing: defaultLetterSpacing,
      lineHeight: defaultLineHeight,
      tabularNumbers: defaultTabularNumbers,
      textBreakStrategy: defaultTextBreakStrategy,
    };

function needsTextMeasureDefaults(style: TextMeasureStyle): boolean {
  'worklet';
  return (
    (style.allowFontScaling === undefined && defaultAllowFontScaling !== undefined) ||
    (style.color === undefined && defaultColor !== undefined) ||
    (style.fontFamily === undefined && defaultFontFamily !== undefined) ||
    (style.fontSize === undefined && defaultFontSize !== undefined) ||
    (style.fontStyle === undefined && defaultFontStyle !== undefined) ||
    (style.fontWeight === undefined && defaultFontWeight !== undefined) ||
    (style.includeFontPadding === undefined && defaultIncludeFontPadding !== undefined) ||
    (style.letterSpacing === undefined && defaultLetterSpacing !== undefined) ||
    (style.lineHeight === undefined && defaultLineHeight !== undefined) ||
    (style.tabularNumbers === undefined && defaultTabularNumbers !== undefined) ||
    (style.textBreakStrategy === undefined && defaultTextBreakStrategy !== undefined)
  );
}

/**
 * Resolves app-wide build-time text defaults against a caller-provided style.
 *
 * The original object is preserved when no defaulted field needs filling.
 */
export function resolveTextMeasureStyle(style: TextMeasureStyle | undefined): TextMeasureStyle | undefined {
  'worklet';
  if (!textMeasureDefaults) return style;
  if (!style) return textMeasureDefaults;
  if (!needsTextMeasureDefaults(style)) return style;

  return {
    allowFontScaling: style.allowFontScaling ?? defaultAllowFontScaling,
    color: style.color ?? defaultColor,
    fontFamily: style.fontFamily ?? defaultFontFamily,
    fontSize: style.fontSize ?? defaultFontSize,
    fontStyle: style.fontStyle ?? defaultFontStyle,
    fontWeight: style.fontWeight ?? defaultFontWeight,
    includeFontPadding: style.includeFontPadding ?? defaultIncludeFontPadding,
    letterSpacing: style.letterSpacing ?? defaultLetterSpacing,
    lineHeight: style.lineHeight ?? defaultLineHeight,
    tabularNumbers: style.tabularNumbers ?? defaultTabularNumbers,
    textBreakStrategy: style.textBreakStrategy ?? defaultTextBreakStrategy,
  };
}

/**
 * Resolves the app-wide cap-height anchoring default for one caller-owned value.
 */
export function resolveAnchorToCapHeight(anchorToCapHeight: boolean | undefined): boolean | undefined {
  'worklet';
  return anchorToCapHeight ?? defaultAnchorToCapHeight;
}

export function shouldResolveAnchorToCapHeight(anchorToCapHeight: boolean | undefined): boolean {
  'worklet';
  return anchorToCapHeight === undefined && defaultAnchorToCapHeight !== undefined;
}

/**
 * Resolves app-wide layout defaults against one width-constrained block layout request.
 */
export function resolveLayoutOptions(options: LayoutOptions): LayoutOptions {
  'worklet';
  const resolvedAnchorToCapHeight = resolveAnchorToCapHeight(options.anchorToCapHeight);
  if (resolvedAnchorToCapHeight === options.anchorToCapHeight) return options;

  return {
    ...options,
    anchorToCapHeight: resolvedAnchorToCapHeight,
  };
}

/**
 * Resolves the glyph-field subset of the app-wide text defaults.
 *
 * `fontSize` and `lineHeight` stay required at the resolved boundary. If the
 * caller omits either one and no build-time default supplies it, the call is
 * rejected before native ownership begins.
 */
export function resolveGlyphFieldConfig(config: GlyphFieldConfig): GlyphFieldConfig {
  const resolvedFontSize = config.fontSize ?? defaultFontSize;
  const resolvedLineHeight = config.lineHeight ?? defaultLineHeight;

  if (resolvedFontSize === undefined) {
    throw new Error('RNTextEngine: createGlyphField() requires fontSize unless react-native-text-engine.config supplies a default.');
  }
  if (resolvedLineHeight === undefined) {
    throw new Error('RNTextEngine: createGlyphField() requires lineHeight unless react-native-text-engine.config supplies a default.');
  }

  const shouldResolve =
    resolvedFontSize !== config.fontSize ||
    resolvedLineHeight !== config.lineHeight ||
    (config.fontFamily === undefined && defaultFontFamily !== undefined) ||
    (config.letterSpacing === undefined && defaultLetterSpacing !== undefined);

  if (!shouldResolve) return config;

  return {
    ...config,
    fontFamily: config.fontFamily ?? defaultFontFamily,
    fontSize: resolvedFontSize,
    letterSpacing: config.letterSpacing ?? defaultLetterSpacing,
    lineHeight: resolvedLineHeight,
  };
}
