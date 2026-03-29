import { codegenNativeComponent, type CodegenTypes, type ColorValue, type ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  color?: ColorValue;
  ellipsizeMode?: string;
  fontFamily?: string;
  fontSize?: CodegenTypes.Double;
  fontStyle?: string;
  fontWeight?: string;
  letterSpacing?: CodegenTypes.Double;
  lineHeight?: CodegenTypes.Double;
  numberOfLines?: CodegenTypes.Int32;
  runColors?: ReadonlyArray<string>;
  runCount?: CodegenTypes.Int32;
  runEnds?: ReadonlyArray<CodegenTypes.Double>;
  runFontFamilies?: ReadonlyArray<string>;
  runFontSizes?: ReadonlyArray<CodegenTypes.Double>;
  runFontStyles?: ReadonlyArray<string>;
  runFontWeights?: ReadonlyArray<string>;
  runLetterSpacings?: ReadonlyArray<CodegenTypes.Double>;
  runLineHeights?: ReadonlyArray<CodegenTypes.Double>;
  runStarts?: ReadonlyArray<CodegenTypes.Double>;
  runStyleMasks?: ReadonlyArray<CodegenTypes.Double>;
  runTabularNumbers?: ReadonlyArray<boolean>;
  selectable?: boolean;
  text?: string;
  textAlign?: string;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineTextView');
