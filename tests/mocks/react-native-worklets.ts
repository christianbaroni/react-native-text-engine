type RuntimeSchedule = {
  fn: () => void;
  runtime: WorkletRuntime;
};

export type WorkletRuntime = {
  readonly config?: object;
  readonly kind: 'mock-worklet-runtime';
};

type WorkletsMockState = {
  createdRuntimes: WorkletRuntime[];
  scheduledCalls: RuntimeSchedule[];
  uiRuntimeHolder: { kind: 'mock-ui-runtime-holder' };
};

export const workletsMockState: WorkletsMockState = {
  createdRuntimes: [],
  scheduledCalls: [],
  uiRuntimeHolder: { kind: 'mock-ui-runtime-holder' },
};

export function resetWorkletsMockState(): void {
  workletsMockState.createdRuntimes = [];
  workletsMockState.scheduledCalls = [];
  workletsMockState.uiRuntimeHolder = { kind: 'mock-ui-runtime-holder' };
}

export function createWorkletRuntime(config?: object): WorkletRuntime {
  const runtime: WorkletRuntime = {
    config,
    kind: 'mock-worklet-runtime',
  };
  workletsMockState.createdRuntimes.push(runtime);
  return runtime;
}

export function getUIRuntimeHolder(): object {
  return workletsMockState.uiRuntimeHolder;
}

export function isRNRuntime(): boolean {
  return true;
}

export function scheduleOnRuntime(runtime: WorkletRuntime, fn: () => void): void {
  workletsMockState.scheduledCalls.push({ fn, runtime });
}
