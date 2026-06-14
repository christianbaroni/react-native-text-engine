import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { findTextEngineConfigPath, syncTextEngineDefaults } from '../scripts/sync-text-engine-config-core.mts';

const tempRoots: string[] = [];
const EMPTY_SOURCE_DEFAULTS =
  "import type { TextEngineDefaults } from '../types';\n\n" +
  'export const textEngineAppDefaults: TextEngineDefaults = {};\n\n' +
  'export default textEngineAppDefaults;\n';
const APP_CONFIG_WITH_DEFAULTS = [
  'export default {',
  '  anchorToCapHeight: true,',
  "  fontFamily: 'TiemposText-Regular',",
  '  fontSize: 17,',
  '  lineHeight: 24,',
  '};',
  '',
].join('\n');

function createTempRoot(): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'rn-text-engine-config-'));
  tempRoots.push(root);
  return root;
}

function createPackageRootAt(packageRoot: string): string {
  fs.mkdirSync(path.join(packageRoot, 'src/generated'), { recursive: true });
  fs.mkdirSync(path.join(packageRoot, 'lib/module/generated'), { recursive: true });
  fs.mkdirSync(path.join(packageRoot, 'lib/commonjs/generated'), { recursive: true });
  return packageRoot;
}

function createPackageRoot(root: string): string {
  return createPackageRootAt(path.join(root, 'package'));
}

function readGenerated(packageRoot: string, relativePath: string): string {
  return fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');
}

function writeGenerated(packageRoot: string, relativePath: string, contents: string): void {
  const targetPath = path.join(packageRoot, relativePath);
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, contents);
}

describe('build-time config sync', () => {
  afterEach(() => {
    while (tempRoots.length > 0) {
      const root = tempRoots.pop();
      if (!root) continue;
      fs.rmSync(root, { force: true, recursive: true });
    }
  });

  it('stays optional and writes stable empty defaults when no config file exists', () => {
    const root = createTempRoot();
    const appRoot = path.join(root, 'app');
    const packageRoot = createPackageRootAt(path.join(appRoot, 'node_modules/react-native-text-engine'));
    fs.mkdirSync(appRoot, { recursive: true });

    const first = syncTextEngineDefaults({ appRoot, packageRoot });
    const second = syncTextEngineDefaults({ appRoot, packageRoot });

    expect(first.configPath).toBeNull();
    expect(first.defaults).toEqual({});
    expect(first.target).toBe('package');
    expect(first.wroteFiles).toHaveLength(3);
    expect(second.wroteFiles).toEqual([]);
    expect(readGenerated(packageRoot, 'src/generated/TextEngineAppDefaults.ts')).toContain(
      'export const textEngineAppDefaults: TextEngineDefaults = {};'
    );
  });

  it('keeps the package source default empty', () => {
    const packageRoot = path.resolve(__dirname, '..');

    expect(readGenerated(packageRoot, 'src/generated/TextEngineAppDefaults.ts')).toContain(
      'export const textEngineAppDefaults: TextEngineDefaults = {};'
    );
  });

  it('loads a TypeScript config file and snapshots defaults into a physical package copy owned by the app', () => {
    const root = createTempRoot();
    const appRoot = path.join(root, 'app');
    const packageRoot = createPackageRootAt(path.join(appRoot, 'node_modules/react-native-text-engine'));
    fs.mkdirSync(appRoot, { recursive: true });
    fs.writeFileSync(path.join(appRoot, 'react-native-text-engine.config.ts'), APP_CONFIG_WITH_DEFAULTS);

    const result = syncTextEngineDefaults({ appRoot, packageRoot });

    expect(findTextEngineConfigPath(appRoot)).toBe(path.join(appRoot, 'react-native-text-engine.config.ts'));
    expect(result.defaults).toEqual({
      anchorToCapHeight: true,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      lineHeight: 24,
    });
    expect(result.target).toBe('package');
    expect(readGenerated(packageRoot, 'src/generated/TextEngineAppDefaults.ts')).toContain('anchorToCapHeight: true');
    expect(readGenerated(packageRoot, 'lib/module/generated/TextEngineAppDefaults.js')).toContain('fontFamily: "TiemposText-Regular"');
    expect(readGenerated(packageRoot, 'lib/commonjs/generated/TextEngineAppDefaults.js')).toContain('lineHeight: 24');
  });

  it('writes source-checkout app defaults to an app overlay without mutating the package source default', () => {
    const root = createTempRoot();
    const packageRoot = createPackageRoot(root);
    const appRoot = path.join(packageRoot, 'examples');
    fs.mkdirSync(appRoot, { recursive: true });
    fs.writeFileSync(path.join(appRoot, 'react-native-text-engine.config.ts'), APP_CONFIG_WITH_DEFAULTS);
    writeGenerated(packageRoot, 'src/generated/TextEngineAppDefaults.ts', EMPTY_SOURCE_DEFAULTS);

    const result = syncTextEngineDefaults({ appRoot, packageRoot });
    const appOverlayPath = path.join(appRoot, 'generated/react-native-text-engine/TextEngineAppDefaults.js');

    expect(result.defaults).toEqual({
      anchorToCapHeight: true,
      fontFamily: 'TiemposText-Regular',
      fontSize: 17,
      lineHeight: 24,
    });
    expect(result.target).toBe('app-overlay');
    expect(readGenerated(packageRoot, 'src/generated/TextEngineAppDefaults.ts')).toBe(EMPTY_SOURCE_DEFAULTS);
    expect(fs.readFileSync(appOverlayPath, 'utf8')).toContain('anchorToCapHeight: true');
    expect(fs.readFileSync(appOverlayPath, 'utf8')).toContain('fontFamily: "TiemposText-Regular"');
  });

  it('rejects unsupported config fields with a direct error', () => {
    const root = createTempRoot();
    const appRoot = path.join(root, 'app');
    const packageRoot = createPackageRoot(root);
    fs.mkdirSync(appRoot, { recursive: true });
    fs.writeFileSync(
      path.join(appRoot, 'react-native-text-engine.config.js'),
      ['module.exports = {', '  unsupported: true,', '};', ''].join('\n')
    );

    expect(() => syncTextEngineDefaults({ appRoot, packageRoot })).toThrow('RNTextEngine: ');
  });
});
