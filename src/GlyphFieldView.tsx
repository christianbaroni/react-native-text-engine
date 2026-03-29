import React, { forwardRef, type ComponentRef } from 'react';
import NativeGlyphFieldView, { type NativeProps as NativeGlyphFieldViewProps } from './specs/RNTextEngineGlyphFieldViewNativeComponent';

/**
 * Props for the native glyph-field render surface.
 *
 * The view renders whatever content currently lives in the referenced
 * `GlyphFieldHandle`. Geometry and variant policy are owned by that handle.
 */
export type GlyphFieldViewProps = NativeGlyphFieldViewProps;

export const GlyphFieldView = forwardRef<ComponentRef<typeof NativeGlyphFieldView>, GlyphFieldViewProps>(
  function GlyphFieldView(props, ref) {
    return <NativeGlyphFieldView ref={ref} {...props} />;
  }
);
