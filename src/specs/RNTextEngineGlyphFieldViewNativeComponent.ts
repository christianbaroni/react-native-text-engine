import { codegenNativeComponent, type CodegenTypes, type ViewProps } from 'react-native';

export interface NativeProps extends ViewProps {
  handle?: CodegenTypes.Double;
}

export default codegenNativeComponent<NativeProps>('RNTextEngineGlyphFieldView');
