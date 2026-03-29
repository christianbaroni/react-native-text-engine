import { getRNTextEngineRuntime } from './initModule';
import type { GlyphFieldConfig, GlyphFieldHandle } from './types';

export class GlyphField implements GlyphFieldHandle {
  readonly handle: number;

  private constructor(handle: number) {
    this.handle = handle;
  }

  static fromHandle(handle: number): GlyphField {
    return new GlyphField(handle);
  }

  update(glyphs: string, variantIndices: Uint8Array): void {
    getRNTextEngineRuntime().updateGlyphField(this.handle, glyphs, variantIndices);
  }

  release(): void {
    getRNTextEngineRuntime().releaseGlyphField(this.handle);
  }

  static create(config: GlyphFieldConfig): GlyphField {
    return GlyphField.fromHandle(getRNTextEngineRuntime().createGlyphField(config));
  }
}

export function createGlyphField(config: GlyphFieldConfig): GlyphField {
  return GlyphField.create(config);
}
