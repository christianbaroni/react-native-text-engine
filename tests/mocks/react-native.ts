import React, { forwardRef } from 'react';

type NativeModule = {
  install?: () => boolean;
};

type NativeModuleMap = Record<string, NativeModule>;
type NativePropsRegistry = Record<string, Record<string, unknown> | undefined>;

const nativeModules: NativeModuleMap = {};
const nativeComponentProps: NativePropsRegistry = {};

export const reactNativeMockState: { nativeModules: NativeModuleMap } = {
  nativeModules,
};

export const NativeModules = nativeModules;

export function resetReactNativeMockState(): void {
  for (const moduleName of Object.keys(nativeModules)) {
    delete nativeModules[moduleName];
  }

  for (const componentName of Object.keys(nativeComponentProps)) {
    delete nativeComponentProps[componentName];
  }
}

export function getLastNativeComponentProps(name: string): Record<string, unknown> | undefined {
  return nativeComponentProps[name];
}

export const TurboModuleRegistry = {
  get(name: string) {
    return reactNativeMockState.nativeModules[name] ?? null;
  },
};

export const StyleSheet = {
  flatten(value: unknown): Record<string, unknown> | undefined {
    if (Array.isArray(value)) {
      return value.reduce<Record<string, unknown>>((result, item): Record<string, unknown> => {
        const flattened = StyleSheet.flatten(item);
        return flattened == null ? result : { ...result, ...flattened };
      }, {});
    }
    return isRecordLike(value) ? value : undefined;
  },
};

export function createMockNativeComponent<Props extends object>(name: string) {
  return forwardRef<unknown, React.PropsWithChildren<Props>>(function MockNativeComponent(props, ref) {
    nativeComponentProps[name] = { ...props, ref };
    return React.createElement('div', { 'data-testid': name }, props.children);
  });
}

function isRecordLike(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
