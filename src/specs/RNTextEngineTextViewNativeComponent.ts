import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { ColorValue, ViewProps } from 'react-native';
import type { Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';

export interface TextShadowOffset {
  height: Double;
  width: Double;
}

export interface NativeProps extends ViewProps {
  allowFontScaling?: boolean;
  anchorToCapHeight?: boolean;
  color?: ColorValue;
  ellipsizeMode?: string;
  fontFamily?: string;
  fontSize?: Double;
  fontStyle?: string;
  fontWeight?: string;
  letterSpacing?: Double;
  lineHeight?: Double;
  numberOfLines?: Int32;
  rnteHasAllowFontScaling?: boolean;
  rnteHasLetterSpacing?: boolean;
  rnteHasTabularNumbers?: boolean;
  rnteIsVirtualTextSpan?: boolean;
  runColors?: ReadonlyArray<string>;
  runCount?: Int32;
  runEnds?: ReadonlyArray<Double>;
  runFontFamilies?: ReadonlyArray<string>;
  runFontSizes?: ReadonlyArray<Double>;
  runFontStyles?: ReadonlyArray<string>;
  runFontWeights?: ReadonlyArray<string>;
  runLetterSpacings?: ReadonlyArray<Double>;
  runLineHeights?: ReadonlyArray<Double>;
  runStarts?: ReadonlyArray<Double>;
  runStyleMasks?: ReadonlyArray<Double>;
  runTabularNumbers?: ReadonlyArray<boolean>;
  selectable?: boolean;
  tabularNumbers?: boolean;
  text?: string;
  textAlign?: string;
  textDecorationColor?: ColorValue;
  textDecorationLine?: string;
  textDecorationStyle?: string;
  textShadowColor?: ColorValue;
  textShadowOffset?: Readonly<TextShadowOffset>;
  textShadowRadius?: Double;
  textTransform?: string;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineTextView');
