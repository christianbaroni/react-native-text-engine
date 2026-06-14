const RECYCLE_THRESHOLD_PX = 10;

function clamp(value: number, lower: number, upper: number): number {
  'worklet';
  return Math.min(Math.max(value, lower), upper);
}

function createIndexTypedArray(length: number): Uint32Array {
  'worklet';
  const indices = new Uint32Array(length);

  for (let i = 0; i < length; i += 1) {
    indices[i] = i;
  }

  return indices;
}

export type FenwickTreeConfig = {
  bufferAbove: number;
  bufferBelow: number;
  gap: number;
  isInverted: boolean;
  itemCount: number;
  listSize: number;
  rowCount: number;
  scrollPaddingEnd: number;
  scrollPaddingStart: number;
};

export class FenwickTree {
  private bufferAbove: number;
  private bufferBelow: number;
  private dirtyFromIndex: number;
  private fenwicks: Float32Array;
  private gap: number;
  private itemCount: number;
  private isInverted: boolean;
  private length: number;
  private listSize: number;
  private offsetCache: Float32Array;
  private prevViewportStartIndex: number;
  private prevWindowStartIndex: number;
  private rowCount: number;
  private rowGlobalIndicesBufferA: Uint32Array;
  private rowGlobalIndicesBufferB: Uint32Array;
  private rowSizes: Float32Array;
  private scrollPaddingEnd: number;
  private scrollPaddingStart: number;
  private scrollOffset: number;
  private totalSize: number;
  private useRowGlobalIndicesBufferA: boolean;

  constructor({
    bufferAbove,
    bufferBelow,
    gap,
    isInverted,
    itemCount,
    listSize,
    rowCount,
    scrollPaddingEnd,
    scrollPaddingStart,
  }: FenwickTreeConfig) {
    this.bufferAbove = bufferAbove;
    this.bufferBelow = bufferBelow;
    this.dirtyFromIndex = 0;
    this.fenwicks = new Float32Array(itemCount + 1);
    this.gap = gap;
    this.itemCount = itemCount;
    this.isInverted = isInverted;
    this.length = itemCount;
    this.listSize = listSize;
    this.offsetCache = new Float32Array(itemCount);
    this.prevViewportStartIndex = 0;
    this.prevWindowStartIndex = 0;
    this.rowCount = rowCount;
    this.rowGlobalIndicesBufferA = createIndexTypedArray(rowCount);
    this.rowGlobalIndicesBufferB = createIndexTypedArray(rowCount);
    this.rowSizes = new Float32Array(itemCount);
    this.scrollPaddingEnd = scrollPaddingEnd;
    this.scrollPaddingStart = scrollPaddingStart;
    this.scrollOffset = 0;
    this.totalSize = 0;
    this.useRowGlobalIndicesBufferA = true;
  }

  buildFromEstimate(rowDataCount: number, estimatedRowSize: number): void {
    const sizes = new Float32Array(rowDataCount);

    for (let i = 0; i < rowDataCount; i += 1) {
      sizes[i] = estimatedRowSize + this.getRowGapSize(i, rowDataCount);
    }

    this.buildFromSizes(sizes, rowDataCount);
  }

  buildFromSizes(sizes: Float32Array | number[], newSize?: number): void {
    const nextSize = newSize ?? sizes.length;
    this.itemCount = nextSize;
    this.length = nextSize;
    this.fenwicks = new Float32Array(nextSize + 1);
    this.offsetCache = new Float32Array(nextSize);
    this.rowSizes = new Float32Array(nextSize);

    let sum = 0;
    for (let i = 0; i < nextSize; i += 1) {
      const size = sizes[i] ?? 0;
      this.rowSizes[i] = size;
      this.fenwicks[i + 1] = size;
      sum += size;
      this.offsetCache[i] = sum;
    }

    for (let i = 1; i <= nextSize; i += 1) {
      const j = i + (i & -i);
      if (j <= nextSize) {
        this.fenwicks[j] += this.fenwicks[i];
      }
    }

    this.dirtyFromIndex = nextSize;
    this.totalSize = sum;
  }

  rebuild(rowDataCount: number, estimatedRowSize: number, nextScrollOffset: number, initialSizes?: Float32Array | number[]): Uint32Array {
    this.scrollOffset = nextScrollOffset;

    if (rowDataCount <= 0) {
      this.itemCount = 0;
      this.length = 0;
      this.fenwicks = new Float32Array(1);
      this.offsetCache = new Float32Array(0);
      this.rowSizes = new Float32Array(0);
      this.totalSize = 0;
      this.prevViewportStartIndex = 0;
      this.prevWindowStartIndex = 0;
      return this.writeWindowIndices(0);
    }

    if (initialSizes && initialSizes.length === rowDataCount) {
      this.buildFromSizes(initialSizes, rowDataCount);
    } else {
      this.buildFromEstimate(rowDataCount, estimatedRowSize);
    }

    const clampedOffset = clamp(nextScrollOffset, 0, this.getMaxOffset());
    const viewportStartIndex = this.findIndexForOffset(clampedOffset);
    const targetWindowStartIndex = this.getTargetWindowStartIndex(viewportStartIndex);
    const nextIndices = this.writeWindowIndices(targetWindowStartIndex);
    this.prevViewportStartIndex = viewportStartIndex;
    this.prevWindowStartIndex = targetWindowStartIndex;
    return nextIndices;
  }

  updateConfig({
    bufferAbove,
    bufferBelow,
    gap,
    isInverted,
    listSize,
    rowCount,
    scrollPaddingEnd,
    scrollPaddingStart,
  }: Omit<FenwickTreeConfig, 'itemCount'>): void {
    this.bufferAbove = bufferAbove;
    this.bufferBelow = bufferBelow;
    this.gap = gap;
    this.isInverted = isInverted;
    this.listSize = listSize;
    if (rowCount !== this.rowCount) {
      this.rowGlobalIndicesBufferA = new Uint32Array(rowCount);
      this.rowGlobalIndicesBufferB = new Uint32Array(rowCount);
      this.useRowGlobalIndicesBufferA = true;
    }
    this.rowCount = rowCount;
    this.scrollPaddingEnd = scrollPaddingEnd;
    this.scrollPaddingStart = scrollPaddingStart;
  }

  findIndexForOffset(targetOffset: number): number {
    if (this.length === 0) {
      return 0;
    }

    if (this.isInverted) {
      return this.findIndexForPrefixAtLeast(this.totalSize - targetOffset);
    }

    let index = 0;
    let bit = 1;
    while (bit <= this.length) {
      bit <<= 1;
    }
    bit >>= 1;

    let remaining = targetOffset;
    while (bit !== 0) {
      const next = index + bit;
      if (next <= this.length && this.fenwicks[next] <= remaining) {
        remaining -= this.fenwicks[next];
        index = next;
      }
      bit >>= 1;
    }

    return index >= this.length ? this.length - 1 : index;
  }

  getOffsetForIndex(index: number): number {
    if (index < 0 || this.length === 0) return 0;
    if (index >= this.length) return this.totalSize;
    if (index < this.dirtyFromIndex) return this.offsetCache[index] ?? 0;

    let sum = 0;
    let current = index + 1;
    while (current > 0) {
      sum += this.fenwicks[current];
      current -= current & -current;
    }

    this.offsetCache[index] = sum;
    return sum;
  }

  getRowStartOffset(rowIndex: number): number {
    if (rowIndex <= 0) return 0;
    if (rowIndex >= this.length) return this.totalSize;
    return this.getOffsetForIndex(rowIndex - 1);
  }

  getRowLayoutStartOffset(rowIndex: number): number {
    if (!this.isInverted) {
      return this.getRowStartOffset(rowIndex);
    }

    return this.totalSize - this.getRowStartOffset(rowIndex + 1);
  }

  getRowLayoutEndOffset(rowIndex: number): number {
    if (!this.isInverted) {
      return this.getRowStartOffset(rowIndex + 1);
    }

    return this.totalSize - this.getRowStartOffset(rowIndex);
  }

  getRowMainSize(rowIndex: number): number {
    if (rowIndex < 0 || rowIndex >= this.length) return 0;
    return (this.rowSizes[rowIndex] ?? 0) - this.getRowGapSize(rowIndex);
  }

  recycleRows(offset: number): Uint32Array | null {
    this.scrollOffset = offset;
    const clampedOffset = clamp(offset, 0, this.getMaxOffset());

    if (this.itemCount === 0 || this.rowCount === 0) {
      return null;
    }

    const prevViewportOffset = this.getRowLayoutStartOffset(this.prevViewportStartIndex);
    if (Math.abs(clampedOffset - prevViewportOffset) < RECYCLE_THRESHOLD_PX) {
      return null;
    }

    const viewportStartIndex = this.findIndexForOffset(clampedOffset);
    const targetWindowStartIndex = this.getTargetWindowStartIndex(viewportStartIndex);
    if (targetWindowStartIndex === this.prevWindowStartIndex) {
      this.prevViewportStartIndex = viewportStartIndex;
      return null;
    }

    const shift = targetWindowStartIndex - this.prevWindowStartIndex;
    const maxIndex = this.itemCount - 1;
    const invalidIndex = this.itemCount;
    const nextIndices = this.publishRowGlobalIndices(indices => {
      const currentIndices = this.getCurrentRowGlobalIndices();
      let didRecycle = false;

      indices.set(currentIndices);

      if (Math.abs(shift) >= this.rowCount) {
        for (let i = 0; i < this.rowCount; i += 1) {
          const candidateIndex = targetWindowStartIndex + i;
          const nextIndex = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[i] === nextIndex) continue;
          indices[i] = nextIndex;
          didRecycle = true;
        }

        return didRecycle ? indices : indices;
      }

      if (shift > 0) {
        for (let i = 0; i < shift; i += 1) {
          let minRow = 0;
          let minVal = indices[0] ?? invalidIndex;

          for (let j = 1; j < this.rowCount; j += 1) {
            const value = indices[j];
            if (value < minVal) {
              minRow = j;
              minVal = value;
            }
          }

          const candidateIndex = targetWindowStartIndex + this.rowCount - shift + i;
          const nextIndex = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[minRow] === nextIndex) continue;
          indices[minRow] = nextIndex;
          didRecycle = true;
        }

        return didRecycle ? indices : indices;
      }

      if (shift < 0) {
        const recycleCount = -shift;

        for (let i = 0; i < recycleCount; i += 1) {
          let maxRow = 0;
          let maxVal = indices[0] ?? invalidIndex;

          for (let j = 1; j < this.rowCount; j += 1) {
            const value = indices[j];
            if (value > maxVal) {
              maxVal = value;
              maxRow = j;
            }
          }

          const candidateIndex = targetWindowStartIndex + i;
          const nextIndex = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[maxRow] === nextIndex) continue;
          indices[maxRow] = nextIndex;
          didRecycle = true;
        }
      }

      return indices;
    });

    this.prevViewportStartIndex = viewportStartIndex;
    this.prevWindowStartIndex = targetWindowStartIndex;
    return nextIndices;
  }

  setScrollOffset(offset: number): Uint32Array | null {
    return this.recycleRows(offset);
  }

  getTotalSize(): number {
    return this.totalSize;
  }

  private findIndexForPrefixAtLeast(target: number): number {
    if (this.length === 0 || target <= 0) {
      return 0;
    }

    if (target >= this.totalSize) {
      return this.length - 1;
    }

    let index = 0;
    let bit = 1;
    while (bit <= this.length) {
      bit <<= 1;
    }
    bit >>= 1;

    let remaining = target;
    while (bit !== 0) {
      const next = index + bit;
      if (next <= this.length && this.fenwicks[next] < remaining) {
        remaining -= this.fenwicks[next];
        index = next;
      }
      bit >>= 1;
    }

    return index;
  }

  private getMaxOffset(): number {
    const maxOffset = this.totalSize + this.scrollPaddingStart + this.scrollPaddingEnd - this.listSize;
    return maxOffset > 0 ? maxOffset : 0;
  }

  private getRowGapSize(rowIndex: number, rowCountOverride?: number): number {
    const rowCount = rowCountOverride ?? this.length;
    if (rowCount <= 1) {
      return 0;
    }

    if (this.isInverted) {
      return rowIndex > 0 ? this.gap : 0;
    }

    return rowIndex < rowCount - 1 ? this.gap : 0;
  }

  private getTargetWindowStartIndex(viewportStartIndex: number): number {
    const maxWindowStartIndex = Math.max(0, this.itemCount - this.rowCount);
    if (!this.isInverted) {
      return clamp(viewportStartIndex - this.bufferAbove, 0, maxWindowStartIndex);
    }

    const visibleRowCount = Math.max(0, this.rowCount - this.bufferAbove - this.bufferBelow);
    const visibleSpan = visibleRowCount > 0 ? visibleRowCount - 1 : 0;
    return clamp(viewportStartIndex - visibleSpan - this.bufferBelow, 0, maxWindowStartIndex);
  }

  private writeWindowIndices(targetWindowStartIndex: number): Uint32Array {
    const maxIndex = this.itemCount - 1;
    const invalidIndex = this.itemCount;
    return this.publishRowGlobalIndices(indices => {
      for (let i = 0; i < this.rowCount; i += 1) {
        const candidateIndex = targetWindowStartIndex + i;
        indices[i] = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
      }

      return indices;
    });
  }

  private getCurrentRowGlobalIndices(): Uint32Array {
    return this.useRowGlobalIndicesBufferA ? this.rowGlobalIndicesBufferA : this.rowGlobalIndicesBufferB;
  }

  private getNextRowGlobalIndices(): Uint32Array {
    return this.useRowGlobalIndicesBufferA ? this.rowGlobalIndicesBufferB : this.rowGlobalIndicesBufferA;
  }

  private publishRowGlobalIndices(fill: (indices: Uint32Array) => Uint32Array): Uint32Array {
    const nextIndices = this.getNextRowGlobalIndices();
    fill(nextIndices);
    this.useRowGlobalIndicesBufferA = !this.useRowGlobalIndicesBufferA;
    return nextIndices;
  }
}
