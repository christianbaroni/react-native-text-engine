import React from 'react';
import { Platform, requireNativeComponent, type ColorValue, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';
import type { TextMeasureRun } from './types';

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
  runs?: readonly TextMeasureRun[];
  selectable?: boolean;
  style?: StyleProp<ViewStyle>;
  text?: string;
  textAlign?: 'auto' | 'center' | 'justify' | 'left' | 'right';
};

const NativeTextView = requireNativeComponent<TextViewProps>('RNPretextTextView');

/**
 * Native text display surface that can be driven directly by animated props.
 */
export const TextView: React.ComponentType<TextViewProps> =
  Platform.OS === 'ios' || Platform.OS === 'android' ? (NativeTextView as unknown as React.ComponentType<TextViewProps>) : () => null;
