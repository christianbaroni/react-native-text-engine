import React from 'react';
import {
  Platform,
  processColor,
  requireNativeComponent,
  type ColorValue,
  type StyleProp,
  type ViewProps,
  type ViewStyle,
} from 'react-native';

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
  style?: StyleProp<ViewStyle>;
  text?: string;
  textAlign?: 'auto' | 'center' | 'justify' | 'left' | 'right';
};

const NativeTextView = requireNativeComponent<TextViewProps>('RNPretextTextView');

export const TextView: React.ComponentType<TextViewProps> =
  Platform.OS === 'ios' || Platform.OS === 'android' ? (NativeTextView as unknown as React.ComponentType<TextViewProps>) : () => null;

export function resolveTextViewColor(color: ColorValue | undefined): ColorValue | number | undefined {
  if (color == null) return undefined;
  return typeof color === 'string' ? (processColor(color) ?? undefined) : color;
}
