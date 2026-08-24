import { getRNTextEngineRuntime } from './initModule';

let didInstallUIRuntime = false;

function getUIRuntimeHolder(): object | undefined {
  const proxy = Reflect.get(globalThis, '__workletsModuleProxy');
  if (typeof proxy !== 'object' || proxy === null) return undefined;

  const getHolder = Reflect.get(proxy, 'getUIRuntimeHolder');
  if (typeof getHolder !== 'function') return undefined;

  const holder = Reflect.apply(getHolder, proxy, []);
  return typeof holder === 'object' && holder !== null ? holder : undefined;
}

export function installTextEngineRuntime(workletRuntime: object, target: string): void {
  const installWorkletRuntime = Reflect.get(globalThis, '__RNTextEngineInstallWorkletRuntime');
  if (typeof installWorkletRuntime !== 'function') {
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
  const installWorkletRuntime = Reflect.get(globalThis, '__RNTextEngineInstallWorkletRuntime');
  if (typeof installWorkletRuntime !== 'function') return;

  if (installWorkletRuntime(uiRuntimeHolder) === true) {
    didInstallUIRuntime = true;
  }
}
