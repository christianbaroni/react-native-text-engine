import { getRNTextEngineRuntime } from './initModule';
import { resolveGlyphFieldConfig } from './textEngineDefaults';
import type { GlyphFieldConfig, GlyphFieldHandle } from './types';
import { installTextEngineUIRuntimeIfPresent } from './workletRuntimeInstall';

export class GlyphField implements GlyphFieldHandle {
  readonly handle: number;

  private constructor(handle: number) {
    this.handle = handle;
  }

  static fromHandle(handle: number): GlyphField {
    return new GlyphField(handle);
  }

  update(glyphs: string, variantIndices: Uint8Array): void;
  update(glyphIndices: Uint8Array, variantIndices: Uint8Array): void;
  update(glyphsOrIndices: string | Uint8Array, variantIndices: Uint8Array): void {
    if (typeof glyphsOrIndices === 'string') getRNTextEngineRuntime().updateGlyphField(this.handle, glyphsOrIndices, variantIndices);
    else getRNTextEngineRuntime().updateGlyphFieldIndices(this.handle, glyphsOrIndices, variantIndices);
  }

  release(): void {
    getRNTextEngineRuntime().releaseGlyphField(this.handle);
  }

  static create(config: GlyphFieldConfig): GlyphField {
    installTextEngineUIRuntimeIfPresent();
    return GlyphField.fromHandle(getRNTextEngineRuntime().createGlyphField(resolveGlyphFieldConfig(config)));
  }
}

export function createGlyphField(config: GlyphFieldConfig): GlyphField {
  return GlyphField.create(config);
}
