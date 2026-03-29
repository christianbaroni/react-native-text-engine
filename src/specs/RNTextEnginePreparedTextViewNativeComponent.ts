import { codegenNativeComponent, type CodegenTypes, type ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  ellipsizeMode?: string;
  handle?: CodegenTypes.Double;
  numberOfLines?: CodegenTypes.Int32;
  selectable?: boolean;
}

export default codegenNativeComponent<NativeProps>('RNTextEnginePreparedTextView');
