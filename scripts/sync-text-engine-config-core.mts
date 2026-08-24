import fs from 'node:fs';
import path from 'node:path';
import { createJiti } from 'jiti';
import type { TextEngineDefaults } from '../src/types';

export type SyncTextEngineDefaultsResult = {
  configPath: string | null;
  defaults: TextEngineDefaults;
  target: SyncTextEngineDefaultsTarget;
  wroteFiles: string[];
};
export type SyncTextEngineDefaultsTarget = 'app-overlay' | 'package';
export type SyncTextEngineDefaultsOptions = {
  appOverlayRoot?: string;
  appRoot: string;
  packageRoot: string;
};

const CONFIG_BASENAME = 'react-native-text-engine.config';
const CONFIG_EXTENSIONS = ['ts', 'cts', 'mts', 'js', 'cjs', 'mjs', 'json'] as const;
export const APP_DEFAULTS_OVERLAY_RELATIVE_PATH = 'generated/react-native-text-engine/TextEngineAppDefaults.js';
const DEFAULT_FIELD_ORDER = [
  'allowFontScaling',
  'anchorToCapHeight',
  'color',
  'fontFamily',
  'fontSize',
  'fontStyle',
  'fontWeight',
  'includeFontPadding',
  'letterSpacing',
  'lineHeight',
  'tabularNumbers',
  'textBreakStrategy',
] as const satisfies readonly (keyof TextEngineDefaults)[];
type TextEngineDefaultKey = (typeof DEFAULT_FIELD_ORDER)[number];
type TextEngineDefaultsArtifact = {
  contents: string;
  path: string;
};

function isRecordLike(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function createConfigLoader(packageRoot: string) {
  return createJiti(import.meta.url, {
    alias: {
      'react-native-text-engine': path.join(packageRoot, 'src/index.ts'),
      'react-native-text-engine/config': path.join(packageRoot, 'src/config.ts'),
      'react-native-text-engine/worklets': path.join(packageRoot, 'src/worklets.ts'),
    },
    fsCache: false,
    interopDefault: true,
    moduleCache: false,
  });
}

function unwrapModuleDefault(value: unknown): unknown {
  if (!isRecordLike(value)) return value;
  if (!('default' in value) || value.default === undefined) return value;
  return value.default;
}

function formatFieldList(values: readonly string[]): string {
  return values.map(value => `"${value}"`).join(', ');
}

function isTextEngineDefaultKey(value: string): value is TextEngineDefaultKey {
  for (const key of DEFAULT_FIELD_ORDER) {
    if (key === value) return true;
  }
  return false;
}

export function findTextEngineConfigPath(appRoot: string): string | null {
  const matches = CONFIG_EXTENSIONS.map(extension => path.join(appRoot, `${CONFIG_BASENAME}.${extension}`)).filter(candidate =>
    fs.existsSync(candidate)
  );

  if (matches.length <= 1) return matches[0] ?? null;

  throw new Error(
    `RNTextEngine: found multiple config files in ${appRoot}. Keep only one of ${formatFieldList(matches.map(candidate => path.basename(candidate)))}.`
  );
}

export function normalizeTextEngineDefaults(value: unknown, sourceLabel: string): TextEngineDefaults {
  if (!isRecordLike(value)) {
    throw new Error(`RNTextEngine: ${sourceLabel} must export a plain object of text defaults.`);
  }

  const normalized: TextEngineDefaults = {};
  const keys = Object.keys(value);

  for (const key of keys) {
    if (!isTextEngineDefaultKey(key)) {
      throw new Error(
        `RNTextEngine: ${sourceLabel} contains unsupported field "${key}". Supported fields are ${formatFieldList(DEFAULT_FIELD_ORDER)}.`
      );
    }
  }

  for (const key of DEFAULT_FIELD_ORDER) {
    const candidate = value[key];
    if (candidate === undefined) continue;

    switch (key) {
      case 'allowFontScaling':
      case 'anchorToCapHeight':
      case 'includeFontPadding':
      case 'tabularNumbers':
        if (typeof candidate !== 'boolean') {
          throw new Error(`RNTextEngine: ${sourceLabel} field "${key}" must be a boolean.`);
        }
        normalized[key] = candidate;
        break;
      case 'fontSize':
      case 'letterSpacing':
      case 'lineHeight':
        if (typeof candidate !== 'number' || !Number.isFinite(candidate)) {
          throw new Error(`RNTextEngine: ${sourceLabel} field "${key}" must be a finite number.`);
        }
        normalized[key] = candidate;
        break;
      case 'color':
      case 'fontFamily':
      case 'fontWeight':
        if (typeof candidate !== 'string') {
          throw new Error(`RNTextEngine: ${sourceLabel} field "${key}" must be a string.`);
        }
        normalized[key] = candidate;
        break;
      case 'fontStyle':
        if (candidate !== 'italic' && candidate !== 'normal') {
          throw new Error(`RNTextEngine: ${sourceLabel} field "${key}" must be one of ${formatFieldList(['italic', 'normal'])}.`);
        }
        normalized[key] = candidate;
        break;
      case 'textBreakStrategy':
        if (candidate !== 'balanced' && candidate !== 'highQuality' && candidate !== 'simple') {
          throw new Error(
            `RNTextEngine: ${sourceLabel} field "${key}" must be one of ${formatFieldList(['balanced', 'highQuality', 'simple'])}.`
          );
        }
        normalized[key] = candidate;
        break;
    }
  }

  return normalized;
}

export function loadTextEngineDefaults(
  appRoot: string,
  packageRoot: string
): {
  configPath: string | null;
  defaults: TextEngineDefaults;
} {
  const configPath = findTextEngineConfigPath(appRoot);
  if (!configPath) {
    return {
      configPath: null,
      defaults: {},
    };
  }

  const rawValue =
    path.extname(configPath) === '.json' ? JSON.parse(fs.readFileSync(configPath, 'utf8')) : createConfigLoader(packageRoot)(configPath);

  return {
    configPath,
    defaults: normalizeTextEngineDefaults(unwrapModuleDefault(rawValue), configPath),
  };
}

function serializeDefaultsLiteral(defaults: TextEngineDefaults): string {
  const lines: string[] = [];

  for (const key of DEFAULT_FIELD_ORDER) {
    const value = defaults[key];
    if (value === undefined) continue;
    lines.push(`  ${key}: ${JSON.stringify(value)},`);
  }

  if (lines.length === 0) return '{}';
  return `{\n${lines.join('\n')}\n}`;
}

export function buildTextEngineDefaultsArtifacts(packageRoot: string, defaults: TextEngineDefaults): TextEngineDefaultsArtifact[] {
  const literal = serializeDefaultsLiteral(defaults);
  const sourceContents =
    "import type { TextEngineDefaults } from '../types';\n\n" +
    `export const textEngineAppDefaults: TextEngineDefaults = ${literal};\n\n` +
    'export default textEngineAppDefaults;\n';
  const moduleContents = `export const textEngineAppDefaults = ${literal};\n\n` + 'export default textEngineAppDefaults;\n';
  const commonjsContents =
    "'use strict';\n\n" +
    `const textEngineAppDefaults = ${literal};\n\n` +
    'exports.textEngineAppDefaults = textEngineAppDefaults;\n' +
    'exports.default = textEngineAppDefaults;\n';

  return [
    {
      contents: sourceContents,
      path: path.join(packageRoot, 'src/generated/TextEngineAppDefaults.ts'),
    },
    {
      contents: moduleContents,
      path: path.join(packageRoot, 'lib/module/generated/TextEngineAppDefaults.js'),
    },
    {
      contents: commonjsContents,
      path: path.join(packageRoot, 'lib/commonjs/generated/TextEngineAppDefaults.js'),
    },
  ];
}

export function buildTextEngineAppDefaultsOverlayArtifacts(appRoot: string, defaults: TextEngineDefaults): TextEngineDefaultsArtifact[] {
  const literal = serializeDefaultsLiteral(defaults);
  return [
    {
      contents: `export const textEngineAppDefaults = ${literal};\n\nexport default textEngineAppDefaults;\n`,
      path: path.join(appRoot, APP_DEFAULTS_OVERLAY_RELATIVE_PATH),
    },
  ];
}

function writeFileIfChanged(targetPath: string, contents: string): boolean {
  const existing = fs.existsSync(targetPath) ? fs.readFileSync(targetPath, 'utf8') : null;
  if (existing === contents) return false;

  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, contents);
  return true;
}

function realPathIfPresent(value: string): string {
  return fs.existsSync(value) ? fs.realpathSync.native(value) : path.resolve(value);
}

function isSameOrDescendantPath(parentPath: string, candidatePath: string): boolean {
  const relativePath = path.relative(parentPath, candidatePath);
  return relativePath === '' || (!relativePath.startsWith('..') && !path.isAbsolute(relativePath));
}

export function resolveTextEngineDefaultsSyncTarget(appRoot: string, packageRoot: string): SyncTextEngineDefaultsTarget {
  const resolvedAppRoot = realPathIfPresent(appRoot);
  const resolvedPackageRoot = realPathIfPresent(packageRoot);

  if (resolvedAppRoot === resolvedPackageRoot) return 'package';
  return isSameOrDescendantPath(resolvedAppRoot, resolvedPackageRoot) ? 'package' : 'app-overlay';
}

export function syncTextEngineDefaults({
  appOverlayRoot,
  appRoot,
  packageRoot,
}: SyncTextEngineDefaultsOptions): SyncTextEngineDefaultsResult {
  const { configPath, defaults } = loadTextEngineDefaults(appRoot, packageRoot);
  const target = resolveTextEngineDefaultsSyncTarget(appRoot, packageRoot);
  const artifacts =
    target === 'package'
      ? buildTextEngineDefaultsArtifacts(packageRoot, defaults)
      : buildTextEngineAppDefaultsOverlayArtifacts(appOverlayRoot ?? appRoot, defaults);
  const wroteFiles = artifacts.filter(artifact => writeFileIfChanged(artifact.path, artifact.contents)).map(artifact => artifact.path);

  return {
    configPath,
    defaults,
    target,
    wroteFiles,
  };
}
