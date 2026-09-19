import type { ViewProps } from 'react-native';
import codegenNativeComponent, { type Double, type Int32 } from './codegen';

export interface NativeProps extends ViewProps {
  anchorToCapHeight?: boolean;
  ellipsizeMode?: string;
  handle?: Double;
  numberOfLines?: Int32;
  selectable?: boolean;
}

export default codegenNativeComponent<NativeProps>('RNTextEnginePreparedTextView');
