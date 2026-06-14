import type { TextEngineDefaults } from './types';

/**
 * Declares app-wide build-time text defaults for `react-native-text-engine`.
 *
 * Export the returned object from `react-native-text-engine.config.{js,ts}`.
 * The native build hooks snapshot that file into the installed package before
 * bundling so the measurement, prepared-text, glyph-field, and non-style
 * render-surface defaults read one consistent build-time policy, without
 * runtime configs.
 */
export function defineTextEngineDefaults(defaults: TextEngineDefaults): TextEngineDefaults {
  return defaults;
}

export type { TextEngineDefaults } from './types';
