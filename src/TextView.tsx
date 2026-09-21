import {
  createContext,
  forwardRef,
  useContext,
  type ForwardRefExoticComponent,
  type PropsWithoutRef,
  type RefAttributes,
  type ComponentRef,
  type ReactNode,
} from 'react';
import type { StyleProp, TextStyle, ViewStyle } from 'react-native';
import textEngineAppDefaults from './generated/TextEngineAppDefaults';
import NativeTextView, { type NativeProps as NativeTextViewProps } from './specs/RNTextEngineTextViewNativeComponent';
import type { TextMeasureRun } from './types';

export type TextViewRunPayload = Readonly<{
  runColors?: readonly string[];
  runCount?: number;
  runEnds: readonly number[];
  runFontFamilies?: readonly string[];
  runFontSizes?: readonly number[];
  runFontStyles?: readonly string[];
  runFontWeights?: readonly string[];
  runLetterSpacings?: readonly number[];
  runLineHeights?: readonly number[];
  runStarts: readonly number[];
  runStyleMasks?: readonly number[];
  runTabularNumbers?: readonly boolean[];
}>;

const RUN_STYLE_HAS_COLOR = 1 << 0;
const RUN_STYLE_HAS_FONT_FAMILY = 1 << 1;
const RUN_STYLE_HAS_FONT_SIZE = 1 << 2;
const RUN_STYLE_HAS_FONT_STYLE = 1 << 3;
const RUN_STYLE_HAS_FONT_WEIGHT = 1 << 4;
const RUN_STYLE_HAS_LETTER_SPACING = 1 << 5;
const RUN_STYLE_HAS_LINE_HEIGHT = 1 << 6;
const RUN_STYLE_HAS_TABULAR_NUMBERS = 1 << 7;

/**
 * Props for the native text display surface.
 *
 * `TextView` is the canonical zero-extra-work render surface. Pass `text`
 * directly on hot paths. The Babel plugin lowers textual JSX children into
 * this prop when it can prove the child model, and uses narrowly-scoped
 * runtime helpers only for dynamic child forwarding boundaries that JSX alone
 * cannot lower losslessly for a custom text host.
 */
type InternalTextViewPropKey = 'rnteHasAllowFontScaling' | 'rnteHasLetterSpacing' | 'rnteHasTabularNumbers' | 'rnteIsVirtualTextSpan';

export type TextViewProps = Omit<NativeTextViewProps, 'style' | InternalTextViewPropKey> & {
  children?: ReactNode;
  style?: StyleProp<ViewStyle & TextStyle>;
};

const textViewNestingContext = createContext(false);

/**
 * Flattens inline runs into the canonical `TextView` prop payload.
 *
 * Call this where the run list is owned or memoized. `TextView` itself does no
 * render-time run packing.
 */
export function createTextViewRunPayload(runs: readonly TextMeasureRun[] | undefined): TextViewRunPayload | undefined {
  'worklet';

  if (!runs || runs.length === 0) return undefined;

  const runCount = runs.length;
  const runStarts = new Array<number>(runCount);
  const runEnds = new Array<number>(runCount);
  const runStyleMasks = new Array<number>(runCount);

  let runColors: string[] | undefined;
  let runFontFamilies: string[] | undefined;
  let runFontSizes: number[] | undefined;
  let runFontStyles: string[] | undefined;
  let runFontWeights: string[] | undefined;
  let runLetterSpacings: number[] | undefined;
  let runLineHeights: number[] | undefined;
  let runTabularNumbers: boolean[] | undefined;

  for (let index = 0; index < runCount; index += 1) {
    const run = runs[index];
    const style = run?.style;
    let styleMask = 0;

    runStarts[index] = run?.start ?? 0;
    runEnds[index] = run?.end ?? 0;

    if (!style) {
      runStyleMasks[index] = styleMask;
      continue;
    }

    if (style.color !== undefined) {
      runColors ??= new Array<string>(runCount).fill('');
      runColors[index] = style.color;
      styleMask |= RUN_STYLE_HAS_COLOR;
    }

    if (style.fontFamily !== undefined) {
      runFontFamilies ??= new Array<string>(runCount).fill('');
      runFontFamilies[index] = style.fontFamily;
      styleMask |= RUN_STYLE_HAS_FONT_FAMILY;
    }

    if (style.fontSize !== undefined) {
      runFontSizes ??= new Array<number>(runCount).fill(0);
      runFontSizes[index] = style.fontSize;
      styleMask |= RUN_STYLE_HAS_FONT_SIZE;
    }

    if (style.fontStyle !== undefined) {
      runFontStyles ??= new Array<string>(runCount).fill('');
      runFontStyles[index] = style.fontStyle;
      styleMask |= RUN_STYLE_HAS_FONT_STYLE;
    }

    if (style.fontWeight !== undefined) {
      runFontWeights ??= new Array<string>(runCount).fill('');
      runFontWeights[index] = style.fontWeight;
      styleMask |= RUN_STYLE_HAS_FONT_WEIGHT;
    }

    if (style.letterSpacing !== undefined) {
      runLetterSpacings ??= new Array<number>(runCount).fill(0);
      runLetterSpacings[index] = style.letterSpacing;
      styleMask |= RUN_STYLE_HAS_LETTER_SPACING;
    }

    if (style.lineHeight !== undefined) {
      runLineHeights ??= new Array<number>(runCount).fill(0);
      runLineHeights[index] = style.lineHeight;
      styleMask |= RUN_STYLE_HAS_LINE_HEIGHT;
    }

    if (style.tabularNumbers !== undefined) {
      runTabularNumbers ??= new Array<boolean>(runCount).fill(false);
      runTabularNumbers[index] = style.tabularNumbers;
      styleMask |= RUN_STYLE_HAS_TABULAR_NUMBERS;
    }

    runStyleMasks[index] = styleMask;
  }

  return {
    runColors,
    runCount,
    runEnds,
    runFontFamilies,
    runFontSizes,
    runFontStyles,
    runFontWeights,
    runLetterSpacings,
    runLineHeights,
    runStarts,
    runStyleMasks,
    runTabularNumbers,
  };
}

/**
 * Native text display surface that can be driven directly by animated props.
 */
export const TextView: ForwardRefExoticComponent<PropsWithoutRef<TextViewProps> & RefAttributes<ComponentRef<typeof NativeTextView>>> =
  forwardRef<ComponentRef<typeof NativeTextView>, TextViewProps>(function TextView(props, ref) {
    const isVirtualTextSpan = useContext(textViewNestingContext);
    return (
      <textViewNestingContext.Provider value>
        <NativeTextView
          ref={ref}
          {...props}
          accessible={props.accessible ?? !isVirtualTextSpan}
          allowFontScaling={props.allowFontScaling ?? textEngineAppDefaults.allowFontScaling}
          anchorToCapHeight={props.anchorToCapHeight ?? textEngineAppDefaults.anchorToCapHeight}
          rnteHasAllowFontScaling={props.allowFontScaling !== undefined}
          rnteHasLetterSpacing={props.letterSpacing !== undefined}
          rnteHasTabularNumbers={props.tabularNumbers !== undefined}
          rnteIsVirtualTextSpan={isVirtualTextSpan}
          tabularNumbers={props.tabularNumbers ?? textEngineAppDefaults.tabularNumbers}
        />
      </textViewNestingContext.Provider>
    );
  });
