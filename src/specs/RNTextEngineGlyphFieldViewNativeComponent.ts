import type { ViewProps } from 'react-native';
import codegenNativeComponent, { type Double } from './codegen';

export interface NativeProps extends ViewProps {
  handle?: Double;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineGlyphFieldView');
