import React from 'react';
import { Platform, requireNativeComponent, type ColorValue, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';
import type { TextMeasureRun } from './types';

export type TextViewRunPayload = Readonly<{
  runColors?: readonly (string | null)[];
  runCount?: number;
  runEnds: readonly number[];
  runFontFamilies?: readonly (string | null)[];
  runFontSizes?: readonly number[];
  runFontStyles?: readonly (string | null)[];
  runFontWeights?: readonly (string | null)[];
  runLetterSpacings?: readonly number[];
  runLineHeights?: readonly number[];
  runStarts: readonly number[];
  runStyleMasks?: readonly number[];
  runTabularNumbers?: readonly boolean[];
}>;

/**
 * Props for the native text display surface.
 *
 * `selectable` opts into the interaction-oriented native text owner. Leave it
 * off for the lowest-cost display path.
 */
export type TextViewProps = ViewProps & {
  color?: ColorValue;
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  fontFamily?: string;
  fontSize?: number;
  fontStyle?: 'italic' | 'normal';
  fontWeight?: string;
  letterSpacing?: number;
  lineHeight?: number;
  numberOfLines?: number;
  runColors?: readonly (string | null)[];
  runCount?: number;
  runEnds?: readonly number[];
  runFontFamilies?: readonly (string | null)[];
  runFontSizes?: readonly number[];
  runFontStyles?: readonly (string | null)[];
  runFontWeights?: readonly (string | null)[];
  runLetterSpacings?: readonly number[];
  runLineHeights?: readonly number[];
  runStarts?: readonly number[];
  runStyleMasks?: readonly number[];
  runTabularNumbers?: readonly boolean[];
  runs?: readonly TextMeasureRun[];
  selectable?: boolean;
  style?: StyleProp<ViewStyle>;
  text?: string;
  textAlign?: 'auto' | 'center' | 'justify' | 'left' | 'right';
};

const NativeTextView = requireNativeComponent<TextViewProps>('RNTextEngineTextView');

/**
 * Native text display surface that can be driven directly by animated props.
 */
export const TextView: React.ComponentType<TextViewProps> =
  Platform.OS === 'ios' || Platform.OS === 'android' ? (NativeTextView as unknown as React.ComponentType<TextViewProps>) : () => null;
