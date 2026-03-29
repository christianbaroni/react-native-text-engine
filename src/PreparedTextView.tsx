import React from 'react';
import { Platform, requireNativeComponent, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';

/**
 * Props for the native prepared-handle render surface.
 *
 * `selectable` opts into the interaction-oriented native text owner. The
 * prepared-handle surface currently renders on iOS only.
 */
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
/**
 * Native prepared-handle render surface.
 */
export const PreparedTextView: React.ComponentType<PreparedTextViewProps> =
  Platform.OS === 'ios' ? (IOSPreparedTextView as unknown as React.ComponentType<PreparedTextViewProps>) : () => null;
