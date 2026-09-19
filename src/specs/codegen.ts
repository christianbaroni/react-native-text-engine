import nativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { HostComponent } from 'react-native';

/** A numeric prop represented as a native double by React Native Codegen. */
export type Double = number;

/** A numeric prop represented as a signed 32-bit integer by React Native Codegen. */
export type Int32 = number;

/** Resolves a registered native view as a React host component. */
const codegenNativeComponent: <Props extends object>(name: string) => HostComponent<Props> = nativeComponent;

export default codegenNativeComponent;
