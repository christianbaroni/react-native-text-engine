import 'react-native';

declare module 'react-native' {
  type NativeComponentOptions = Readonly<{
    excludedPlatforms?: readonly string[];
    interfaceOnly?: boolean;
    paperComponentName?: string;
  }>;

  export function codegenNativeComponent<Props extends object>(
    componentName: string,
    options?: NativeComponentOptions
  ): HostComponent<Props>;

  export namespace CodegenTypes {
    type Double = number;
    type Int32 = number;
  }
}

export {};
