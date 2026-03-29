import React, { forwardRef, type ComponentRef } from 'react';
import NativePreparedTextView, {
  type NativeProps as NativePreparedTextViewProps,
} from './specs/RNTextEnginePreparedTextViewNativeComponent';

/**
 * Props for the native prepared-handle render surface.
 *
 * `selectable` opts into the interaction-oriented native text owner.
 */
export type PreparedTextViewProps = NativePreparedTextViewProps & {
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  handle?: number;
  numberOfLines?: number;
};

/**
 * Native prepared-handle render surface.
 */
export const PreparedTextView = forwardRef<ComponentRef<typeof NativePreparedTextView>, PreparedTextViewProps>(
  function PreparedTextView(props, ref) {
    return <NativePreparedTextView ref={ref} {...props} />;
  }
);
