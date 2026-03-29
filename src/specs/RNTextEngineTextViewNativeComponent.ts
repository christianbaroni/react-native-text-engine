import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';
import type { ColorValue, HostComponent, ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  color?: ColorValue;
  ellipsizeMode?: string;
  fontFamily?: string;
  fontSize?: Double;
  fontStyle?: string;
  fontWeight?: string;
  letterSpacing?: Double;
  lineHeight?: Double;
  numberOfLines?: Int32;
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
  text?: string;
  textAlign?: string;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineTextView') as HostComponent<NativeProps>;
