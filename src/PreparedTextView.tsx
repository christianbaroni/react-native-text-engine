import React from 'react';
import { Platform, requireNativeComponent, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';

export type PreparedTextViewProps = ViewProps & {
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  handle?: number;
  numberOfLines?: number;
  selectable?: boolean;
  style?: StyleProp<ViewStyle>;
};

const IOSPreparedTextView = requireNativeComponent<PreparedTextViewProps>('RNPretextPreparedTextView');

// `requireNativeComponent` exposes a HostComponent type that is incompatible
// with this package's React type surface in TS, even though it is the correct
// native render target for animated prop updates.
export const PreparedTextView: React.ComponentType<PreparedTextViewProps> =
  Platform.OS === 'ios' ? (IOSPreparedTextView as unknown as React.ComponentType<PreparedTextViewProps>) : () => null;
