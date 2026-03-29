import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import type { HostComponent, ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  handle?: Double;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineGlyphFieldView') as HostComponent<NativeProps>;
