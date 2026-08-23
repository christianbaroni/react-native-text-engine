import { beforeEach, describe, expect, it, vi } from 'vitest';
import { clearRuntimeBindings, installRuntimeBindings } from './support/runtimeBindings';
import type { TextEngineDefaults } from '../src/types';

function clearWorkletBindings(): void {
  const bindingNames = [
    '__RNTextEngineCommitGlyphFieldBuffers',
    '__RNTextEngineCreateGlyphFieldBuffers',
    '__RNTextEngineUpdateGlyphField',
    '__RNTextEngineUpdateGlyphFieldIndices',
  ];

  for (const name of bindingNames) {
    Reflect.deleteProperty(globalThis, name);
  }
}

async function importWorklets() {
  return import('../src/worklets');
}

function installTextEngineDefaults(defaults: TextEngineDefaults): void {
  vi.doMock('../src/generated/TextEngineAppDefaults', () => ({
    default: defaults,
    textEngineAppDefaults: defaults,
  }));
}

describe('worklet runtime contract', () => {
  beforeEach(async () => {
    vi.resetModules();
    vi.doUnmock('../src/generated/TextEngineAppDefaults');
    clearRuntimeBindings();
    clearWorkletBindings();
    Reflect.deleteProperty(globalThis, '__workletsModuleProxy');
    const { reactNativeMockState } = await import('./mocks/react-native');
    const { resetWorkletsMockState } = await import('./mocks/react-native-worklets');

    resetWorkletsMockState();

    for (const key of Object.keys(reactNativeMockState.nativeModules)) {
      delete reactNativeMockState.nativeModules[key];
    }
  });

  it('installs the UI runtime when the worklets entrypoint loads', async () => {
    const bindings = installRuntimeBindings();

    const { workletsMockState } = await import('./mocks/react-native-worklets');
    await importWorklets();

    expect(bindings.installWorkletRuntime).toHaveBeenCalledWith(workletsMockState.uiRuntimeHolder);
  });

  it('installs an available UI runtime before creating glyph fields and shares that installation with the worklets entrypoint', async () => {
    const bindings = installRuntimeBindings();
    const { workletsMockState } = await import('./mocks/react-native-worklets');
    Reflect.set(globalThis, '__workletsModuleProxy', {
      getUIRuntimeHolder: () => workletsMockState.uiRuntimeHolder,
    });
    const { createGlyphField } = await import('../src/GlyphField');
    const config = { columns: 2, fontSize: 14, lineHeight: 18, rows: 1, variants: [{ color: '#fff' }] };

    createGlyphField(config);
    createGlyphField(config);
    await importWorklets();

    expect(bindings.installWorkletRuntime).toHaveBeenCalledExactlyOnceWith(workletsMockState.uiRuntimeHolder);
    expect(bindings.installWorkletRuntime).toHaveBeenCalledBefore(bindings.createGlyphField);
  });

  it('initializes RN bindings itself before installing the UI runtime and allocating glyph handles', async () => {
    const events: string[] = [];
    const getHolder = vi.fn(() => ({}));
    Reflect.set(globalThis, '__workletsModuleProxy', { getUIRuntimeHolder: getHolder });
    const { reactNativeMockState } = await import('./mocks/react-native');
    const install = vi.fn(() => {
      events.push('RN install');
      const bindings = installRuntimeBindings();
      bindings.installWorkletRuntime.mockImplementation(() => {
        events.push('UI install');
        return true;
      });
      bindings.createGlyphField.mockImplementation(() => {
        events.push('glyph allocation');
        return 201;
      });
      return true;
    });
    reactNativeMockState.nativeModules.RNTextEngine = { install };
    const { installTextEngineUIRuntimeIfPresent } = await import('../src/workletRuntimeInstall');
    const { createGlyphField } = await import('../src/GlyphField');
    const config = { columns: 2, fontSize: 14, lineHeight: 18, rows: 1, variants: [{ color: '#fff' }] };

    installTextEngineUIRuntimeIfPresent();
    createGlyphField(config);
    createGlyphField(config);

    expect(events).toEqual(['RN install', 'UI install', 'glyph allocation', 'glyph allocation']);
    expect(install).toHaveBeenCalledOnce();
    expect(getHolder).toHaveBeenCalledOnce();
  });

  it('retries automatic installation when Worklets appears late or native installation has not succeeded', async () => {
    const bindings = installRuntimeBindings();
    const { createGlyphField } = await import('../src/GlyphField');
    const config = { columns: 2, fontSize: 14, lineHeight: 18, rows: 1, variants: [{ color: '#fff' }] };

    createGlyphField(config);
    expect(bindings.installWorkletRuntime).not.toHaveBeenCalled();

    const holder = {};
    Reflect.set(globalThis, '__workletsModuleProxy', { getUIRuntimeHolder: () => holder });
    bindings.installWorkletRuntime.mockReturnValueOnce(false);
    createGlyphField(config);
    createGlyphField(config);
    createGlyphField(config);

    expect(bindings.installWorkletRuntime).toHaveBeenCalledTimes(2);
    expect(bindings.installWorkletRuntime).toHaveBeenLastCalledWith(holder);
    expect(bindings.createGlyphField).toHaveBeenCalledTimes(4);
  });

  it('keeps glyph creation available when native Worklets integration is absent', async () => {
    const bindings = installRuntimeBindings();
    Reflect.deleteProperty(globalThis, '__RNTextEngineInstallWorkletRuntime');
    Reflect.set(globalThis, '__workletsModuleProxy', { getUIRuntimeHolder: () => ({}) });
    const { createGlyphField } = await import('../src/GlyphField');

    expect(createGlyphField({ columns: 2, fontSize: 14, lineHeight: 18, rows: 1, variants: [{ color: '#fff' }] }).handle).toBe(201);
    expect(bindings.installWorkletRuntime).not.toHaveBeenCalled();
  });

  it('does not allocate a glyph handle when automatic runtime installation throws', async () => {
    const bindings = installRuntimeBindings();
    Reflect.set(globalThis, '__workletsModuleProxy', { getUIRuntimeHolder: () => ({}) });
    bindings.installWorkletRuntime.mockImplementation(() => {
      throw new Error('Native runtime installation failed');
    });
    const { createGlyphField } = await import('../src/GlyphField');

    expect(() => createGlyphField({ columns: 2, fontSize: 14, lineHeight: 18, rows: 1, variants: [{ color: '#fff' }] })).toThrow(
      'Native runtime installation failed'
    );
    expect(bindings.createGlyphField).not.toHaveBeenCalled();
  });

  it('requires the native Worklets runtime install hook', async () => {
    installRuntimeBindings();
    Reflect.deleteProperty(globalThis, '__RNTextEngineInstallWorkletRuntime');

    await expect(importWorklets()).rejects.toThrow('RNTextEngine: Native installWorkletRuntime() is unavailable in this build.');
  });

  it('creates a dedicated worklet runtime, installs the text engine, and schedules the initializer after install', async () => {
    const bindings = installRuntimeBindings();
    const initializer = vi.fn(() => undefined);

    const { createTextEngineRuntime } = await importWorklets();
    const { workletsMockState } = await import('./mocks/react-native-worklets');
    const runtime = createTextEngineRuntime({
      initializer,
      name: 'layout-runtime',
    });

    expect(bindings.installWorkletRuntime).toHaveBeenNthCalledWith(1, workletsMockState.uiRuntimeHolder);
    expect(bindings.installWorkletRuntime).toHaveBeenNthCalledWith(2, runtime);
    expect(workletsMockState.createdRuntimes).toEqual([runtime]);
    expect(workletsMockState.scheduledCalls).toHaveLength(1);
    expect(workletsMockState.scheduledCalls[0]?.runtime).toEqual(runtime);
    expect(workletsMockState.scheduledCalls[0]?.fn).toBe(initializer);
  });

  it('surfaces a hard error when a created runtime cannot be installed natively', async () => {
    const bindings = installRuntimeBindings();
    const { workletsMockState } = await import('./mocks/react-native-worklets');
    bindings.installWorkletRuntime.mockImplementation(runtime => runtime === workletsMockState.uiRuntimeHolder);

    const { createTextEngineRuntime } = await importWorklets();

    expect(() => createTextEngineRuntime({ name: 'broken-runtime' })).toThrow(
      'RNTextEngine: Failed to install bindings into the created worklet runtime.'
    );
  });

  it('applies app-wide defaults across worklet measurement and line-layout helpers', async () => {
    installTextEngineDefaults({
      anchorToCapHeight: true,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      lineHeight: 24,
    });

    const bindings = installRuntimeBindings();
    const { createPreparedTextsInRuntime, layoutNextLineInRuntime, layoutPreparedTextsInRuntime, measureTextsInRuntime } =
      await importWorklets();

    const handles = createPreparedTextsInRuntime(['alpha'], undefined);
    measureTextsInRuntime(['alpha'], undefined, { width: 140 });
    layoutPreparedTextsInRuntime(handles, { width: 140 });
    layoutNextLineInRuntime(handles[0] ?? 0, 0, 140);

    expect(bindings.prepareBatch).toHaveBeenCalledWith(
      ['alpha'],
      {
        fontFamily: 'TiemposText-Regular',
        fontSize: 17,
        lineHeight: 24,
      },
      undefined
    );
    expect(bindings.measureBatch).toHaveBeenCalledWith(
      ['alpha'],
      {
        fontFamily: 'TiemposText-Regular',
        fontSize: 17,
        lineHeight: 24,
      },
      { anchorToCapHeight: true, width: 140 },
      undefined
    );
    expect(bindings.layoutBatch).toHaveBeenCalledWith([20], { anchorToCapHeight: true, width: 140 });
    expect(bindings.layoutNextLine).toHaveBeenCalledWith(20, 0, 140, true);
  });
});
