import { getRNTextEngineRuntime } from './initModule';

type NativeFunction = (...args: unknown[]) => unknown;

let didInstallUIRuntime = false;

function isNativeFunction(value: unknown): value is NativeFunction {
  return typeof value === 'function';
}

function getUIRuntimeHolder(): object | undefined {
  const proxy = Reflect.get(globalThis, '__workletsModuleProxy');
  if (typeof proxy !== 'object' || proxy === null) return undefined;

  const getHolder = Reflect.get(proxy, 'getUIRuntimeHolder');
  if (!isNativeFunction(getHolder)) return undefined;

  const holder = Reflect.apply(getHolder, proxy, []);
  return typeof holder === 'object' && holder !== null ? holder : undefined;
}

function getInstallWorkletRuntime(): NativeFunction | undefined {
  const install = Reflect.get(globalThis, '__RNTextEngineInstallWorkletRuntime');
  return isNativeFunction(install) ? install : undefined;
}

export function installTextEngineRuntime(workletRuntime: object, target: string): void {
  const installWorkletRuntime = getInstallWorkletRuntime();
  if (!installWorkletRuntime) {
    throw new Error('RNTextEngine: Native installWorkletRuntime() is unavailable in this build.');
  }

  if (installWorkletRuntime(workletRuntime) !== true) {
    throw new Error(`RNTextEngine: Failed to install bindings into the ${target} runtime.`);
  }
}

export function installTextEngineUIRuntime(uiRuntimeHolder: object): void {
  if (didInstallUIRuntime) return;

  getRNTextEngineRuntime();
  installTextEngineRuntime(uiRuntimeHolder, 'UI worklet');
  didInstallUIRuntime = true;
}

export function installTextEngineUIRuntimeIfPresent(): void {
  if (didInstallUIRuntime) return;

  const uiRuntimeHolder = getUIRuntimeHolder();
  if (!uiRuntimeHolder) return;

  getRNTextEngineRuntime();
  const installWorkletRuntime = getInstallWorkletRuntime();
  if (!installWorkletRuntime) return;

  if (installWorkletRuntime(uiRuntimeHolder) === true) {
    didInstallUIRuntime = true;
  }
}
