import { getRNPretextRuntime } from './initModule';
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
    getRNPretextRuntime().updateGlyphField(this.handle, glyphs, variantIndices);
  }

  release(): void {
    getRNPretextRuntime().releaseGlyphField(this.handle);
  }

  static create(config: GlyphFieldConfig): GlyphField {
    return GlyphField.fromHandle(getRNPretextRuntime().createGlyphField(config));
  }
}

export function createGlyphField(config: GlyphFieldConfig): GlyphField {
  return GlyphField.create(config);
}
