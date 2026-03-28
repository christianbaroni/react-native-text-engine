/**
 * Opaque identifier for a prepared native text block.
 *
 * Handles are returned by `prepare()` / `prepareBatch()` and must be released
 * when the caller no longer needs them.
 */
export type PreparedTextHandle = Readonly<{
  id: number;
}>;

/**
 * Text style facts that affect native React Native text measurement.
 *
 * This intentionally mirrors the small, high-value subset needed for accurate
 * sizing in real UI paths instead of trying to expose the entire Text style
 * surface.
 */
export type TextMeasureStyle = {
  allowFontScaling?: boolean;
  color?: string;
  fontFamily?: string;
  fontSize?: number;
  fontStyle?: 'italic' | 'normal';
  fontWeight?: string;
  includeFontPadding?: boolean;
  letterSpacing?: number;
  lineHeight?: number;
  tabularNumbers?: boolean;
  textBreakStrategy?: 'balanced' | 'highQuality' | 'simple';
};

/**
 * Width-constrained layout request against a prepared text block.
 */
export type LayoutOptions = {
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  maxLines?: number;
  width: number;
};

/**
 * Aggregate layout metrics for one text block at one width.
 */
export type TextLayout = {
  height: number;
  lastLineWidth: number;
  lineCount: number;
  width: number;
};

/**
 * Visible line geometry reported by the native text engine.
 *
 * `start` and `end` are UTF-16 offsets into the original string, matching
 * React Native/native string indexing semantics.
 */
export type TextLine = {
  bottom: number;
  end: number;
  index: number;
  start: number;
  width: number;
};

/**
 * One width-constrained visible line beginning at a caller-provided text offset.
 *
 * `start` and `end` are absolute UTF-16 offsets into the original text.
 */
export type NextTextLine = {
  bottom: number;
  end: number;
  start: number;
  width: number;
};

/**
 * Full line geometry result for one width-constrained text block.
 */
export type TextLayoutLines = TextLayout & {
  lines: TextLine[];
};
