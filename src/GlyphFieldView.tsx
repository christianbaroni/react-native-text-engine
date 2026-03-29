import { Platform, requireNativeComponent, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';

/**
 * Props for the native glyph-field render surface.
 *
 * The view renders whatever content currently lives in the referenced
 * `GlyphFieldHandle`. Geometry and variant policy are owned by that handle.
 */
export type GlyphFieldViewProps = ViewProps & {
  handle?: number;
  style?: StyleProp<ViewStyle>;
};

export const GlyphFieldView =
  Platform.OS === 'ios' || Platform.OS === 'android'
    ? requireNativeComponent<GlyphFieldViewProps>('RNPretextGlyphFieldView')
    : () => null;
