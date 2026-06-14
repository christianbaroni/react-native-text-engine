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

export const APP_DEFAULTS_OVERLAY_RELATIVE_PATH: string;

export function findTextEngineConfigPath(appRoot: string): string | null;
export function normalizeTextEngineDefaults(value: unknown, sourceLabel: string): TextEngineDefaults;
export function loadTextEngineDefaults(
  appRoot: string,
  packageRoot: string
): {
  configPath: string | null;
  defaults: TextEngineDefaults;
};
export function buildTextEngineDefaultsArtifacts(
  packageRoot: string,
  defaults: TextEngineDefaults
): Array<{ contents: string; path: string }>;
export function buildTextEngineAppDefaultsOverlayArtifacts(
  appRoot: string,
  defaults: TextEngineDefaults
): Array<{ contents: string; path: string }>;
export function resolveTextEngineDefaultsSyncTarget(appRoot: string, packageRoot: string): SyncTextEngineDefaultsTarget;
export function syncTextEngineDefaults(args: SyncTextEngineDefaultsOptions): SyncTextEngineDefaultsResult;
