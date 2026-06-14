import { codegenNativeComponent, type ViewProps } from 'react-native';
import type { Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';

export interface NativeProps extends ViewProps {
  anchorToCapHeight?: boolean;
  ellipsizeMode?: string;
  handle?: Double;
  numberOfLines?: Int32;
  selectable?: boolean;
}

export default codegenNativeComponent<NativeProps>('RNTextEnginePreparedTextView');
