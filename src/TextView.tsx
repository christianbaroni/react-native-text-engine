import React from 'react';
import { Platform, requireNativeComponent, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';

export type TextViewProps = ViewProps & {
  color?: string;
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

const IOSTextView = requireNativeComponent<TextViewProps>('RNPretextTextView');

export const TextView: React.ComponentType<TextViewProps> =
  Platform.OS === 'ios'
    ? (IOSTextView as unknown as React.ComponentType<TextViewProps>)
    : () => null;
