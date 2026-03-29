import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';
import type { HostComponent, ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  ellipsizeMode?: string;
  handle?: Double;
  numberOfLines?: Int32;
  selectable?: boolean;
}

export default codegenNativeComponent<NativeProps>('RNTextEnginePreparedTextView') as HostComponent<NativeProps>;
