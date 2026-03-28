import React, { ComponentProps, memo, useCallback, useEffect, useMemo, useRef } from 'react';
import { type Insets, type NativeScrollEvent, StyleSheet, View, type ViewStyle } from 'react-native';
import Animated, {
  type AnimatedRef,
  type DerivedValue,
  isSharedValue,
  scrollTo,
  useAnimatedReaction,
  useAnimatedRef,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import { runOnUI } from 'react-native-worklets';
import { useWorkletClass } from './useWorkletClass';

// ============ Types ========================================================== //

type ItemSizeConfig<T> =
  | {
      estimatedItemSize: number;
      getItemSize: (index: number, item: T) => number;
      itemMetricsVersion?: undefined;
      itemSizes?: undefined;
      itemSize?: undefined;
    }
  | {
      estimatedItemSize: number;
      getItemSize?: undefined;
      itemMetricsVersion?: SharedValue<number>;
      itemSizes: SharedValue<Float32Array>;
      itemSize?: undefined;
    }
  | {
      estimatedItemSize?: undefined;
      getItemSize?: undefined;
      itemMetricsVersion?: undefined;
      itemSizes?: undefined;
      itemSize: number;
    };

type RowBufferConfig =
  | number
  | {
      above: number;
      below: number;
    };

type RowWindowConfig = {
  bufferAbove: number;
  bufferBelow: number;
  rowCount: number;
  visibleRowCount: number;
};

type VisibleRowRange = {
  endRow: number;
  startRow: number;
};

type AnchorAlignment = 'center' | 'end' | 'start';

export type MaintainVisibleContentIndicesStrategy = 'closestToEnd' | 'closestToStart' | 'firstVisible';

export type MaintainVisibleContentIndices = {
  align?: AnchorAlignment;
  indices: ReadonlyArray<number> | SharedValue<ReadonlyArray<number>>;
  strategy?: MaintainVisibleContentIndicesStrategy;
};

type ScrollEdge = 'end' | 'start';

type MaintainScrollMode = 'always' | 'whenNearEdge';

/**
 * Keeps scroll anchored to a data edge (`start` = data[0], `end` = data[data.length - 1]).
 * `mode: 'whenNearEdge'` only pins when within `maxDistanceFromEdge` scroll pixels of that edge.
 */
export type MaintainScrollAtEdge =
  | boolean
  | {
      edge?: ScrollEdge;
      maxDistanceFromEdge?: number;
      mode?: MaintainScrollMode;
    };

export type MaintainVisibleContentPosition = {
  anchor?: ScrollEdge;
  minIndexForVisible?: number;
};

type PositionAnchor = {
  anchorEdge: ScrollEdge;
  anchorOffset: number;
  key: string;
  kind: 'position';
};

type IndicesAnchor = {
  anchorEdge: AnchorAlignment;
  anchorOffset: number;
  index: number;
  kind: 'indices';
};

type MaintainAnchor = IndicesAnchor | PositionAnchor;

type MaintainIndicesConfig = {
  align: AnchorAlignment;
  indices: ReadonlyArray<number> | SharedValue<ReadonlyArray<number>>;
  strategy: MaintainVisibleContentIndicesStrategy;
};

type MaintainPositionConfig = {
  anchorEdge: ScrollEdge;
  minIndexForVisible: number;
};

type MaintainScrollAtEdgeConfig = {
  edge: ScrollEdge;
  maxDistanceFromEdge: number;
  mode: MaintainScrollMode;
};

type MaintainConfig = {
  indices: MaintainIndicesConfig | null;
  position: MaintainPositionConfig | null;
  stickToEdge: MaintainScrollAtEdgeConfig | null;
};

type InitialTreeState = {
  initialOffsets: Float32Array;
  initialSizes: Float32Array | undefined;
  rowDataCount: number;
  rowGlobalIndices: Uint32Array;
  totalSize: number;
};

type RowMetrics = {
  offsets: Float32Array;
  rowDataCount: number;
  sizes: Float32Array | undefined;
  totalSize: number;
};

type ScrollPadding = {
  end: number;
  start: number;
};

export type RenderItemProps<T> = {
  columnIndex: number;
  data: SharedValue<T[]>;
  fenwickTree: SharedValue<FenwickTree | undefined>;
  isActive: DerivedValue<boolean>;
  itemIndex: DerivedValue<number>;
  rowIndex: DerivedValue<number>;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
};

type AnimatedScrollViewProps = ComponentProps<typeof Animated.ScrollView>;

/**
 * Worklet callback for scroll events.
 * Must include `worklet` directive in the function body.
 */
export type ScrollEventCallback = (event: NativeScrollEvent) => void;

export type AnimatedListProps<T> = {
  columnGap?: number;
  contentContainerStyle?: AnimatedScrollViewProps['contentContainerStyle'];
  data: SharedValue<T[]>;
  gap: number;
  itemWidth: number;
  keyExtractor: (item: T, index: number) => string;
  horizontal?: boolean;
  inverted?: boolean;
  listHeight: number;
  listWidth: number;
  maintainVisibleContentIndices?: MaintainVisibleContentIndices;
  maintainVisibleContentPosition?: MaintainVisibleContentPosition;
  maintainScrollAtEdge?: MaintainScrollAtEdge;
  numColumns?: number;
  /**
   * Worklet callback invoked on each scroll event.
   * Must include `worklet` directive in the function body.
   * @example
   * onScroll={(event) => {
   *   'worklet';
   *   console.log(event.contentOffset.y);
   * }}
   */
  onScroll?: ScrollEventCallback;
  renderItem: (props: RenderItemProps<T>) => React.ReactNode;
  rowBuffer?: RowBufferConfig;
  scrollIndicatorInsets?: Insets;
  /**
   * Shared value updated with the current scroll offset.
   * Useful for driving scroll-based animations like header fades.
   * @example
   * const scrollOffset = useSharedValue(0);
   * <AnimatedList scrollOffset={scrollOffset} ... />
   */
  scrollOffset?: SharedValue<number>;
  style?: AnimatedScrollViewProps['style'];
} & ItemSizeConfig<T>;

// ============ Recycling Functions ============================================ //

const DEFAULT_COLUMN_GAP = 0;
const DEFAULT_NUM_COLUMNS = 1;
const RECYCLE_THRESHOLD_PX = 10;
const ROW_BUFFER: RowBufferConfig = 8;

function clamp(value: number, lower: number, upper: number): number {
  'worklet';
  return Math.min(Math.max(value, lower), upper);
}

function getRowWindowConfig({
  gap,
  listSize,
  rowBuffer,
  rowSize,
}: {
  gap: number;
  listSize: number;
  rowBuffer: RowBufferConfig;
  rowSize: number;
}): RowWindowConfig {
  const rowStride: number = rowSize + gap;
  const visibleRowCount: number = rowStride > 0 ? Math.ceil(listSize / rowStride) : 0;
  const bufferConfig: { bufferAbove: number; bufferBelow: number } = resolveRowBuffer(rowBuffer);

  const bufferAbove: number = bufferConfig.bufferAbove;
  const bufferBelow: number = bufferConfig.bufferBelow;
  const rowCount: number = visibleRowCount + bufferAbove + bufferBelow;

  return { bufferAbove, bufferBelow, rowCount, visibleRowCount };
}

function createIndexArray(length: number): number[] {
  const indices: number[] = new Array(length);

  for (let i = 0; i < length; i += 1) {
    indices[i] = i;
  }

  return indices;
}

function createIndexTypedArray(length: number): Uint32Array {
  'worklet';
  const indices: Uint32Array = new Uint32Array(length);

  for (let i = 0; i < length; i += 1) {
    indices[i] = i;
  }

  return indices;
}

function resolveRowBuffer(rowBuffer: RowBufferConfig): {
  bufferAbove: number;
  bufferBelow: number;
} {
  if (typeof rowBuffer === 'number') {
    const bufferAbove: number = Math.ceil(rowBuffer / 2);
    const bufferBelow: number = Math.floor(rowBuffer / 2);
    return { bufferAbove, bufferBelow };
  }

  return { bufferAbove: rowBuffer.above, bufferBelow: rowBuffer.below };
}

function getRowGap({
  gap,
  isInverted,
  rowCount,
  rowIndex,
}: {
  gap: number;
  isInverted: boolean;
  rowCount: number;
  rowIndex: number;
}): number {
  'worklet';
  if (rowCount <= 1) {
    return 0;
  }

  if (isInverted) {
    return rowIndex > 0 ? gap : 0;
  }

  return rowIndex < rowCount - 1 ? gap : 0;
}

function getItemIndexForRow({
  columnIndex,
  dataLength,
  numColumns,
  rowIndex,
}: {
  columnIndex: number;
  dataLength: number;
  numColumns: number;
  rowIndex: number;
}): number {
  'worklet';
  if (rowIndex < 0) {
    return -1;
  }

  const startIndex: number = rowIndex * numColumns;
  const index: number = startIndex + columnIndex;
  if (index < 0 || index >= dataLength) {
    return -1;
  }

  return index;
}

function buildRowMetrics<T>({
  data,
  estimatedRowSize,
  gap,
  getItemSize,
  itemSizes,
  isInverted,
  numColumns,
}: {
  data: T[];
  estimatedRowSize: number;
  gap: number;
  getItemSize: ((index: number, item: T) => number) | undefined;
  itemSizes: Float32Array | undefined;
  isInverted: boolean;
  numColumns: number;
}): RowMetrics {
  'worklet';
  const itemCount: number = data.length;
  const rowDataCount: number = itemCount > 0 ? Math.ceil(itemCount / numColumns) : 0;
  if (rowDataCount === 0) {
    return {
      offsets: new Float32Array(0),
      rowDataCount: 0,
      sizes: undefined,
      totalSize: 0,
    };
  }

  if (!getItemSize && !itemSizes) {
    const offsets: Float32Array = new Float32Array(rowDataCount);
    let sum = 0;

    for (let rowIndex = 0; rowIndex < rowDataCount; rowIndex += 1) {
      offsets[rowIndex] = sum;
      const gapSize: number = getRowGap({
        gap,
        isInverted,
        rowCount: rowDataCount,
        rowIndex,
      });
      sum += estimatedRowSize + gapSize;
    }

    return { offsets, rowDataCount, sizes: undefined, totalSize: sum };
  }

  const sizes: Float32Array = new Float32Array(rowDataCount);
  const offsets: Float32Array = new Float32Array(rowDataCount);
  let sum = 0;

  for (let rowIndex = 0; rowIndex < rowDataCount; rowIndex += 1) {
    offsets[rowIndex] = sum;
    const startIndex: number = rowIndex * numColumns;
    const endIndex: number = Math.min(startIndex + numColumns, itemCount);
    let maxSize = 0;

    for (let i: number = startIndex; i < endIndex; i += 1) {
      let itemSizeValue = 0;
      if (itemSizes) itemSizeValue = itemSizes[i] ?? 0;
      else if (getItemSize) itemSizeValue = getItemSize(i, data[i]);

      if (itemSizeValue > maxSize) {
        maxSize = itemSizeValue;
      }
    }

    const gapSize: number = getRowGap({
      gap,
      isInverted,
      rowCount: rowDataCount,
      rowIndex,
    });
    const rowSize: number = maxSize + gapSize;
    sizes[rowIndex] = rowSize;
    sum += rowSize;
  }

  return { offsets, rowDataCount, sizes, totalSize: sum };
}

function buildInitialTreeState<T>({
  data,
  estimatedRowSize,
  gap,
  getItemSize,
  itemSizes,
  isInverted,
  numColumns,
  rowCount,
}: {
  data: T[];
  estimatedRowSize: number;
  gap: number;
  getItemSize: ((index: number, item: T) => number) | undefined;
  itemSizes: Float32Array | undefined;
  isInverted: boolean;
  numColumns: number;
  rowCount: number;
}): InitialTreeState {
  'worklet';

  const metrics: RowMetrics = buildRowMetrics({
    data,
    estimatedRowSize,
    gap,
    getItemSize,
    itemSizes,
    isInverted,
    numColumns,
  });
  const rowGlobalIndices: Uint32Array = createIndexTypedArray(rowCount);

  return {
    initialOffsets: metrics.offsets,
    initialSizes: metrics.sizes,
    rowDataCount: metrics.rowDataCount,
    rowGlobalIndices,
    totalSize: metrics.totalSize,
  };
}

function getStyleNumber(style: object, key: string): number | undefined {
  const value: unknown = Reflect.get(style, key);
  return typeof value === 'number' ? value : undefined;
}

function resolveScrollPadding({
  contentContainerStyle,
  isHorizontal,
}: {
  contentContainerStyle: AnimatedScrollViewProps['contentContainerStyle'] | undefined;
  isHorizontal: boolean;
}): ScrollPadding {
  const flattened: unknown = StyleSheet.flatten(contentContainerStyle);
  if (!flattened || typeof flattened !== 'object') {
    return { end: 0, start: 0 };
  }

  const basePadding: number = getStyleNumber(flattened, 'padding') ?? 0;
  const horizontalPadding: number = getStyleNumber(flattened, 'paddingHorizontal') ?? basePadding;
  const verticalPadding: number = getStyleNumber(flattened, 'paddingVertical') ?? basePadding;

  if (isHorizontal) {
    const start: number = getStyleNumber(flattened, 'paddingStart') ?? getStyleNumber(flattened, 'paddingLeft') ?? horizontalPadding;
    const end: number = getStyleNumber(flattened, 'paddingEnd') ?? getStyleNumber(flattened, 'paddingRight') ?? horizontalPadding;
    return { end, start };
  }

  const start: number = getStyleNumber(flattened, 'paddingTop') ?? verticalPadding;
  const end: number = getStyleNumber(flattened, 'paddingBottom') ?? verticalPadding;
  return { end, start };
}

// ============ Maintain Visible Content ======================================= //

const DEFAULT_MAINTAIN_SCROLL_MODE: MaintainScrollMode = 'whenNearEdge';
const DEFAULT_MAINTAIN_SCROLL_DATA_EDGE: ScrollEdge = 'end';
const DEFAULT_MAINTAIN_SCROLL_MAX_DISTANCE = 0;

function resolveIndicesSource(source: ReadonlyArray<number> | SharedValue<ReadonlyArray<number>>): ReadonlyArray<number> {
  'worklet';
  return isSharedValue<ReadonlyArray<number>>(source) ? source.value : source;
}

function resolveMaintainIndicesConfig(config: MaintainVisibleContentIndices | undefined): MaintainIndicesConfig | null {
  if (!config) {
    return null;
  }

  return {
    align: config.align ?? 'start',
    indices: config.indices,
    strategy: config.strategy ?? 'firstVisible',
  };
}

function resolveMaintainPositionConfig(config: MaintainVisibleContentPosition | undefined): MaintainPositionConfig | null {
  if (!config) {
    return null;
  }

  return {
    anchorEdge: config.anchor ?? 'start',
    minIndexForVisible: config.minIndexForVisible ?? 0,
  };
}

function resolveMaintainScrollAtEdgeConfig(config: MaintainScrollAtEdge | undefined): MaintainScrollAtEdgeConfig | null {
  if (!config) {
    return null;
  }

  if (config === true) {
    return {
      edge: DEFAULT_MAINTAIN_SCROLL_DATA_EDGE,
      maxDistanceFromEdge: DEFAULT_MAINTAIN_SCROLL_MAX_DISTANCE,
      mode: DEFAULT_MAINTAIN_SCROLL_MODE,
    };
  }

  return {
    edge: config.edge ?? DEFAULT_MAINTAIN_SCROLL_DATA_EDGE,
    maxDistanceFromEdge: config.maxDistanceFromEdge ?? DEFAULT_MAINTAIN_SCROLL_MAX_DISTANCE,
    mode: config.mode ?? DEFAULT_MAINTAIN_SCROLL_MODE,
  };
}

function resolveMaintainConfig({
  maintainScrollAtEdge,
  maintainVisibleContentIndices,
  maintainVisibleContentPosition,
}: {
  maintainScrollAtEdge: MaintainScrollAtEdge | undefined;
  maintainVisibleContentIndices: MaintainVisibleContentIndices | undefined;
  maintainVisibleContentPosition: MaintainVisibleContentPosition | undefined;
}): MaintainConfig {
  return {
    indices: resolveMaintainIndicesConfig(maintainVisibleContentIndices),
    position: resolveMaintainPositionConfig(maintainVisibleContentPosition),
    stickToEdge: resolveMaintainScrollAtEdgeConfig(maintainScrollAtEdge),
  };
}

function getMaxScrollOffset({
  listSize,
  scrollPaddingEnd,
  scrollPaddingStart,
  totalSize,
}: {
  listSize: number;
  scrollPaddingEnd: number;
  scrollPaddingStart: number;
  totalSize: number;
}): number {
  'worklet';
  const maxOffset: number = totalSize + scrollPaddingStart + scrollPaddingEnd - listSize;
  return maxOffset > 0 ? maxOffset : 0;
}

function getRowIndexFromItemIndex({ index, numColumns }: { index: number; numColumns: number }): number {
  'worklet';
  return Math.floor(index / numColumns);
}

function resolveScrollEdgeToScrollEdge({ edge, isInverted }: { edge: ScrollEdge; isInverted: boolean }): ScrollEdge {
  'worklet';
  if (!isInverted) {
    return edge;
  }

  return edge === 'start' ? 'end' : 'start';
}

function getRowEdgeOffset({ anchorEdge, rowIndex, tree }: { anchorEdge: AnchorAlignment; rowIndex: number; tree: FenwickTree }): number {
  'worklet';
  const rowStart: number = tree.getRowLayoutStartOffset(rowIndex);
  const rowEnd: number = tree.getRowLayoutEndOffset(rowIndex);
  if (anchorEdge === 'center') {
    return rowStart + (rowEnd - rowStart) / 2;
  }

  if (anchorEdge === 'end') {
    return rowEnd;
  }

  return rowStart;
}

function getLastVisibleRowIndex({ listSize, scrollOffset, tree }: { listSize: number; scrollOffset: number; tree: FenwickTree }): number {
  'worklet';
  const viewportEnd: number = scrollOffset + listSize;
  const candidate: number = tree.findIndexForOffset(viewportEnd);
  const candidateStart: number = tree.getRowLayoutStartOffset(candidate);
  if (candidateStart >= viewportEnd && candidate > 0) {
    return candidate - 1;
  }

  return candidate;
}

function getVisibleRowRange({
  listSize,
  scrollOffset,
  tree,
}: {
  listSize: number;
  scrollOffset: number;
  tree: FenwickTree;
}): VisibleRowRange {
  'worklet';
  const firstVisibleRow: number = tree.findIndexForOffset(scrollOffset);
  const lastVisibleRow: number = getLastVisibleRowIndex({
    listSize,
    scrollOffset,
    tree,
  });
  const startRow: number = Math.min(firstVisibleRow, lastVisibleRow);
  const endRow: number = Math.max(firstVisibleRow, lastVisibleRow);
  return { endRow, startRow };
}

function findItemIndexByKey<T>({
  data,
  key,
  keyExtractor,
}: {
  data: T[];
  key: string;
  keyExtractor: (item: T, index: number) => string;
}): number {
  'worklet';
  for (let i = 0; i < data.length; i += 1) {
    const item: T = data[i];
    if (keyExtractor(item, i) === key) {
      return i;
    }
  }

  return -1;
}

function capturePositionAnchor<T>({
  anchorEdge,
  data,
  keyExtractor,
  listSize,
  minIndexForVisible,
  numColumns,
  scrollOffset,
  tree,
}: {
  anchorEdge: ScrollEdge;
  data: T[];
  keyExtractor: (item: T, index: number) => string;
  listSize: number;
  minIndexForVisible: number;
  numColumns: number;
  scrollOffset: number;
  tree: FenwickTree;
}): PositionAnchor | null {
  'worklet';
  const dataLength: number = data.length;
  if (dataLength === 0) {
    return null;
  }

  const minVisibleRow: number = Math.floor(minIndexForVisible / numColumns);
  const firstVisibleRow: number = tree.findIndexForOffset(scrollOffset);
  if (firstVisibleRow < minVisibleRow) {
    return null;
  }

  let anchorRowIndex: number = firstVisibleRow;
  let anchorItemIndex: number = Math.min(dataLength - 1, anchorRowIndex * numColumns);
  let anchorOffset: number = tree.getRowLayoutStartOffset(anchorRowIndex) - scrollOffset;

  if (anchorEdge === 'end') {
    anchorRowIndex = getLastVisibleRowIndex({ listSize, scrollOffset, tree });
    anchorItemIndex = Math.min(dataLength - 1, (anchorRowIndex + 1) * numColumns - 1);
    anchorOffset = tree.getRowLayoutEndOffset(anchorRowIndex) - scrollOffset;
  }

  const item: T | undefined = data[anchorItemIndex];
  if (!item) {
    return null;
  }

  const key: string = keyExtractor(item, anchorItemIndex);
  return { anchorEdge, anchorOffset, key, kind: 'position' };
}

function captureIndicesAnchor({
  align,
  dataLength,
  indices,
  listSize,
  numColumns,
  scrollOffset,
  strategy,
  tree,
}: {
  align: AnchorAlignment;
  dataLength: number;
  indices: ReadonlyArray<number> | SharedValue<ReadonlyArray<number>>;
  listSize: number;
  numColumns: number;
  scrollOffset: number;
  strategy: MaintainVisibleContentIndicesStrategy;
  tree: FenwickTree;
}): IndicesAnchor | null {
  'worklet';
  if (dataLength === 0) {
    return null;
  }

  const candidates: ReadonlyArray<number> = resolveIndicesSource(indices);
  if (candidates.length === 0) {
    return null;
  }

  const { endRow, startRow }: VisibleRowRange = getVisibleRowRange({
    listSize,
    scrollOffset,
    tree,
  });

  let anchorIndex = -1;
  let bestDistance: number = Number.POSITIVE_INFINITY;
  const viewportEnd: number = scrollOffset + listSize;

  for (let i = 0; i < candidates.length; i += 1) {
    const candidate: number = candidates[i];
    if (candidate < 0 || candidate >= dataLength) {
      continue;
    }

    const rowIndex: number = getRowIndexFromItemIndex({
      index: candidate,
      numColumns,
    });
    if (rowIndex < startRow || rowIndex > endRow) {
      continue;
    }

    if (strategy === 'firstVisible') {
      anchorIndex = candidate;
      break;
    }

    if (strategy === 'closestToStart') {
      const rowStart: number = tree.getRowLayoutStartOffset(rowIndex);
      const distance: number = Math.abs(rowStart - scrollOffset);
      if (distance < bestDistance) {
        bestDistance = distance;
        anchorIndex = candidate;
      }
      continue;
    }

    const rowEnd: number = tree.getRowLayoutEndOffset(rowIndex);
    const distance: number = Math.abs(rowEnd - viewportEnd);
    if (distance < bestDistance) {
      bestDistance = distance;
      anchorIndex = candidate;
    }
  }

  if (anchorIndex < 0) {
    return null;
  }

  const anchorRowIndex: number = getRowIndexFromItemIndex({
    index: anchorIndex,
    numColumns,
  });
  const anchorOffset: number = getRowEdgeOffset({ anchorEdge: align, rowIndex: anchorRowIndex, tree }) - scrollOffset;
  return {
    anchorEdge: align,
    anchorOffset,
    index: anchorIndex,
    kind: 'indices',
  };
}

function getScrollEdgeOffset({ maxOffset, scrollEdge }: { maxOffset: number; scrollEdge: ScrollEdge }): number {
  'worklet';
  return scrollEdge === 'start' ? 0 : maxOffset;
}

function getScrollEdgeDistance({
  maxOffset,
  scrollEdge,
  scrollOffset,
}: {
  maxOffset: number;
  scrollEdge: ScrollEdge;
  scrollOffset: number;
}): number {
  'worklet';
  const clampedOffset: number = clamp(scrollOffset, 0, maxOffset);
  return scrollEdge === 'start' ? clampedOffset : maxOffset - clampedOffset;
}

function getStickToEdgeTarget({
  maxDistanceFromEdge,
  mode,
  edge,
  isInverted,
  maxOffset,
  prevMaxOffset,
  prevScrollOffset,
}: {
  maxDistanceFromEdge: number;
  mode: MaintainScrollMode;
  edge: ScrollEdge;
  isInverted: boolean;
  maxOffset: number;
  prevMaxOffset: number;
  prevScrollOffset: number;
}): number | null {
  'worklet';
  const scrollEdge: ScrollEdge = resolveScrollEdgeToScrollEdge({
    edge,
    isInverted,
  });
  if (mode === 'always') {
    return getScrollEdgeOffset({ maxOffset, scrollEdge });
  }

  const prevDistance: number = getScrollEdgeDistance({
    maxOffset: prevMaxOffset,
    scrollEdge,
    scrollOffset: prevScrollOffset,
  });
  if (prevDistance <= maxDistanceFromEdge) {
    return getScrollEdgeOffset({ maxOffset, scrollEdge });
  }

  return null;
}

function scrollToOffset({
  isHorizontal,
  offset,
  scrollViewRef,
}: {
  isHorizontal: boolean;
  offset: number;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
}): void {
  'worklet';
  const xOffset: number = isHorizontal ? offset : 0;
  const yOffset: number = isHorizontal ? 0 : offset;
  scrollTo(scrollViewRef, xOffset, yOffset, false);
}

function getMaintainAnchorOffset<T>({
  anchor,
  data,
  keyExtractor,
  maxOffset,
  numColumns,
  tree,
}: {
  anchor: MaintainAnchor;
  data: T[];
  keyExtractor: (item: T, index: number) => string;
  maxOffset: number;
  numColumns: number;
  tree: FenwickTree;
}): number | null {
  'worklet';
  let targetIndex = -1;

  if (anchor.kind === 'position') {
    targetIndex = findItemIndexByKey({ data, key: anchor.key, keyExtractor });
  } else {
    targetIndex = anchor.index;
  }

  if (targetIndex < 0 || targetIndex >= data.length) {
    return null;
  }

  const rowIndex: number = getRowIndexFromItemIndex({
    index: targetIndex,
    numColumns,
  });
  const rowEdgeOffset: number = getRowEdgeOffset({
    anchorEdge: anchor.anchorEdge,
    rowIndex,
    tree,
  });
  const nextOffset: number = clamp(rowEdgeOffset - anchor.anchorOffset, 0, maxOffset);

  return nextOffset;
}

// ============ Fenwick Tree Helpers =========================================== //

class FenwickTree {
  private __workletClass = true;

  private bufferAbove: number;
  private bufferBelow: number;
  private dirtyFromIndex: number;
  private fenwicks: Float32Array;
  private gap: number;
  private isHorizontal: boolean;
  private itemCount: number;
  private isInverted: boolean;
  private length: number;
  private listSize: number;
  private offsetCache: Float32Array;
  private maintainConfig: MaintainConfig;
  private pendingScrollTarget: SharedValue<number>;
  private prevViewportStartIndex: number;
  private prevWindowStartIndex: number;
  private rowCount: number;
  private rowDataCount: SharedValue<number>;
  private rowGlobalIndices: SharedValue<Uint32Array>;
  private rowSizes: Float32Array;
  private scrollPaddingEnd: number;
  private scrollPaddingStart: number;
  private scrollViewOffset: SharedValue<number>;
  private scrollViewRef: AnimatedRef<Animated.ScrollView>;
  private totalSize: SharedValue<number>;

  constructor({
    bufferAbove,
    bufferBelow,
    gap,
    isHorizontal,
    isInverted,
    itemCount,
    listSize,
    maintainConfig,
    pendingScrollTarget,
    rowCount,
    rowDataCount,
    rowGlobalIndices,
    scrollPaddingEnd,
    scrollPaddingStart,
    scrollOffset,
    scrollViewRef,
    totalSize,
  }: {
    bufferAbove: number;
    bufferBelow: number;
    gap: number;
    isHorizontal: boolean;
    isInverted: boolean;
    itemCount: number;
    listSize: number;
    maintainConfig: MaintainConfig;
    pendingScrollTarget: SharedValue<number>;
    rowCount: number;
    rowDataCount: SharedValue<number>;
    rowGlobalIndices: SharedValue<Uint32Array>;
    scrollPaddingEnd: number;
    scrollPaddingStart: number;
    scrollOffset: SharedValue<number>;
    scrollViewRef: AnimatedRef<Animated.ScrollView>;
    totalSize: SharedValue<number>;
  }) {
    this.bufferAbove = bufferAbove;
    this.bufferBelow = bufferBelow;
    this.dirtyFromIndex = 0;
    this.fenwicks = new Float32Array(itemCount + 1);
    this.gap = gap;
    this.isHorizontal = isHorizontal;
    this.itemCount = itemCount;
    this.isInverted = isInverted;
    this.length = itemCount;
    this.listSize = listSize;
    this.maintainConfig = maintainConfig;
    this.offsetCache = new Float32Array(itemCount);
    this.pendingScrollTarget = pendingScrollTarget;
    this.prevViewportStartIndex = 0;
    this.prevWindowStartIndex = 0;
    this.rowCount = rowCount;
    this.rowDataCount = rowDataCount;
    this.rowGlobalIndices = rowGlobalIndices;
    this.rowSizes = new Float32Array(itemCount);
    this.scrollPaddingEnd = scrollPaddingEnd;
    this.scrollPaddingStart = scrollPaddingStart;
    this.scrollViewOffset = scrollOffset;
    this.scrollViewRef = scrollViewRef;
    this.totalSize = totalSize;
  }

  buildFromEstimate(rowDataCount: number, estimatedRowSize: number): void {
    const sizes: Float32Array = new Float32Array(rowDataCount);

    for (let i = 0; i < rowDataCount; i += 1) {
      sizes[i] = estimatedRowSize + this.getRowGapSize(i, rowDataCount);
    }

    this.buildFromSizes(sizes, rowDataCount);
  }

  buildFromSizes(sizes: Float32Array | number[], newSize?: number): void {
    const nextSize: number = newSize ?? sizes.length;
    this.itemCount = nextSize;
    this.length = nextSize;
    this.fenwicks = new Float32Array(nextSize + 1);
    this.offsetCache = new Float32Array(nextSize);
    this.rowSizes = new Float32Array(nextSize);

    let sum = 0;
    for (let i = 0; i < nextSize; i += 1) {
      const size: number = sizes[i] ?? 0;
      this.rowSizes[i] = size;
      this.fenwicks[i + 1] = size;
      sum += size;
      this.offsetCache[i] = sum;
    }

    for (let i = 1; i <= nextSize; i += 1) {
      const j: number = i + (i & -i);
      if (j <= nextSize) {
        this.fenwicks[j] += this.fenwicks[i];
      }
    }

    this.dirtyFromIndex = nextSize;
    this.totalSize.value = sum;
  }

  appendRow(rowSize: number): void {
    const prevScrollOffset: number = this.scrollViewOffset.value;
    const prevMaxOffset: number = this.getMaxOffset();

    const nextRowCount: number = this.length + 1;
    if (!this.isInverted && this.length > 0) {
      this.rowSizes[this.length - 1] += this.gap;
      this.update(this.length - 1, this.gap);
      this.totalSize.value += this.gap;
    }

    const idx = this.length + 1;
    if (idx >= this.fenwicks.length) {
      this.grow(this.fenwicks.length * 2);
    }

    const rowSizeWithGap: number = rowSize + this.getRowGapSize(nextRowCount - 1, nextRowCount);
    this.rowSizes[this.length] = rowSizeWithGap;

    const lsb = idx & -idx;
    let val = rowSizeWithGap;
    for (let bit = 1; bit < lsb; bit <<= 1) {
      val += this.fenwicks[idx - bit];
    }
    this.fenwicks[idx] = val;

    this.length += 1;
    this.itemCount += 1;
    this.totalSize.value += rowSizeWithGap;
    this.rowDataCount.value = this.itemCount;
    this.invalidateCache(this.length - 1);
    this.applyMaintainScrollAtEdge(prevScrollOffset, prevMaxOffset);
  }

  private applyMaintainScrollAtEdge(prevScrollOffset: number, prevMaxOffset: number): void {
    const stickConfig: MaintainScrollAtEdgeConfig | null = this.maintainConfig.stickToEdge;
    if (!stickConfig) {
      return;
    }

    const newMaxOffset: number = this.getMaxOffset();
    const scrollEdge: ScrollEdge = resolveScrollEdgeToScrollEdge({
      edge: stickConfig.edge,
      isInverted: this.isInverted,
    });
    const targetOffset: number = scrollEdge === 'start' ? 0 : newMaxOffset;

    if (stickConfig.mode === 'always') {
      this.scrollToOffset(targetOffset);
      return;
    }

    const prevDistance: number = getScrollEdgeDistance({
      maxOffset: prevMaxOffset,
      scrollEdge,
      scrollOffset: prevScrollOffset,
    });

    if (prevDistance <= stickConfig.maxDistanceFromEdge) {
      this.scrollToOffset(targetOffset);
    }
  }

  private scrollToOffset(offset: number): void {
    this.pendingScrollTarget.value = offset;
  }

  private applyScroll(offset: number): void {
    const xOffset: number = this.isHorizontal ? offset : 0;
    const yOffset: number = this.isHorizontal ? 0 : offset;
    scrollTo(this.scrollViewRef, xOffset, yOffset, true);
  }

  applyPendingScroll(): void {
    const target: number = this.pendingScrollTarget.value;
    if (target < 0) {
      return;
    }

    this.applyScroll(target);
    this.pendingScrollTarget.value = -1;
  }

  private grow(capacity: number): void {
    const fenwicks = new Float32Array(capacity);
    fenwicks.set(this.fenwicks);
    this.fenwicks = fenwicks;

    const dataCapacity = capacity - 1;
    const rowSizes = new Float32Array(dataCapacity);
    rowSizes.set(this.rowSizes);
    this.rowSizes = rowSizes;

    const offsetCache = new Float32Array(dataCapacity);
    offsetCache.set(this.offsetCache);
    this.offsetCache = offsetCache;
  }

  rebuild(rowDataCount: number, estimatedRowSize: number, initialSizes?: Float32Array | number[]): void {
    if (rowDataCount <= 0) {
      this.itemCount = 0;
      this.length = 0;
      this.fenwicks = new Float32Array(1);
      this.offsetCache = new Float32Array(0);
      this.rowSizes = new Float32Array(0);
      this.totalSize.value = 0;
      this.prevViewportStartIndex = 0;
      this.prevWindowStartIndex = 0;
      this.writeWindowIndices(0);
      return;
    }

    if (initialSizes && initialSizes.length === rowDataCount) {
      this.buildFromSizes(initialSizes, rowDataCount);
    } else {
      this.buildFromEstimate(rowDataCount, estimatedRowSize);
    }

    const offset: number = this.scrollViewOffset.value;
    const maxOffset: number = this.getMaxOffset();
    const clampedOffset: number = clamp(offset, 0, maxOffset);
    const viewportStartIndex: number = this.findIndexForOffset(clampedOffset);
    const targetWindowStartIndex: number = this.getTargetWindowStartIndex(viewportStartIndex);
    this.writeWindowIndices(targetWindowStartIndex);
    this.prevViewportStartIndex = viewportStartIndex;
    this.prevWindowStartIndex = targetWindowStartIndex;
  }

  updateConfig({
    bufferAbove,
    bufferBelow,
    gap,
    isHorizontal,
    isInverted,
    listSize,
    maintainConfig,
    rowCount,
    scrollPaddingEnd,
    scrollPaddingStart,
  }: {
    bufferAbove: number;
    bufferBelow: number;
    gap: number;
    isHorizontal: boolean;
    isInverted: boolean;
    listSize: number;
    maintainConfig: MaintainConfig;
    rowCount: number;
    scrollPaddingEnd: number;
    scrollPaddingStart: number;
  }): void {
    this.bufferAbove = bufferAbove;
    this.bufferBelow = bufferBelow;
    this.gap = gap;
    this.isHorizontal = isHorizontal;
    this.isInverted = isInverted;
    this.listSize = listSize;
    this.maintainConfig = maintainConfig;
    this.rowCount = rowCount;
    this.scrollPaddingEnd = scrollPaddingEnd;
    this.scrollPaddingStart = scrollPaddingStart;
  }

  setRowSize(rowIndex: number, rowSize: number): void {
    if (rowIndex < 0 || rowIndex >= this.length) {
      return;
    }

    const sizeWithGap: number = rowSize + this.getRowGapSize(rowIndex);
    const prevSize: number = this.rowSizes[rowIndex] ?? 0;
    if (prevSize === sizeWithGap) {
      return;
    }

    const prevScrollOffset: number = this.scrollViewOffset.value;
    const prevMaxOffset: number = this.getMaxOffset();
    const delta: number = sizeWithGap - prevSize;
    this.rowSizes[rowIndex] = sizeWithGap;
    this.update(rowIndex, delta);
    this.totalSize.value = this.totalSize.value + delta;

    this.applyMaintainScrollAtEdge(prevScrollOffset, prevMaxOffset);
  }

  findIndexForOffset(targetOffset: number): number {
    if (this.length === 0) {
      return 0;
    }

    if (this.isInverted) {
      const target: number = this.totalSize.value - targetOffset;
      return this.findIndexForPrefixAtLeast(target);
    }

    let index = 0;
    let bit = 1;
    while (bit <= this.length) {
      bit <<= 1;
    }
    bit >>= 1;

    let remaining: number = targetOffset;
    while (bit !== 0) {
      const next: number = index + bit;
      if (next <= this.length && this.fenwicks[next] <= remaining) {
        remaining -= this.fenwicks[next];
        index = next;
      }
      bit >>= 1;
    }

    const candidate: number = index;
    if (candidate >= this.length) {
      return this.length - 1;
    }

    return candidate;
  }

  getOffsetForIndex(i: number): number {
    if (i < 0) return 0;
    if (this.length === 0) return 0;
    if (i >= this.length) return this.totalSize.value;

    if (i < this.dirtyFromIndex) {
      return this.offsetCache[i] ?? 0;
    }

    let sum = 0;
    let index: number = i + 1;
    while (index > 0) {
      sum += this.fenwicks[index];
      index -= index & -index;
    }

    this.offsetCache[i] = sum;
    return sum;
  }

  getRowStartOffset(rowIndex: number): number {
    if (rowIndex <= 0) {
      return 0;
    }
    if (rowIndex >= this.length) {
      return this.totalSize.value;
    }

    return this.getOffsetForIndex(rowIndex - 1);
  }

  getRowLayoutStartOffset(rowIndex: number): number {
    if (!this.isInverted) {
      return this.getRowStartOffset(rowIndex);
    }

    const rowEnd: number = this.getRowStartOffset(rowIndex + 1);
    return this.totalSize.value - rowEnd;
  }

  getRowLayoutEndOffset(rowIndex: number): number {
    if (!this.isInverted) {
      return this.getRowStartOffset(rowIndex + 1);
    }

    const rowStart: number = this.getRowStartOffset(rowIndex);
    return this.totalSize.value - rowStart;
  }

  getRowMainSize(rowIndex: number): number {
    'worklet';
    if (rowIndex < 0 || rowIndex >= this.length) return 0;

    const storedSize: number = this.rowSizes[rowIndex] ?? 0;
    return storedSize - this.getRowGapSize(rowIndex);
  }

  recycleRows(): void {
    const offset: number = this.scrollViewOffset.value;
    const maxOffset: number = this.getMaxOffset();
    const clampedOffset: number = clamp(offset, 0, maxOffset);

    if (this.itemCount === 0 || this.rowCount === 0) {
      return;
    }

    const prevViewportOffset: number = this.getRowLayoutStartOffset(this.prevViewportStartIndex);
    if (Math.abs(clampedOffset - prevViewportOffset) < RECYCLE_THRESHOLD_PX) {
      return;
    }

    const viewportStartIndex: number = this.findIndexForOffset(clampedOffset);
    const targetWindowStartIndex: number = this.getTargetWindowStartIndex(viewportStartIndex);

    if (targetWindowStartIndex === this.prevWindowStartIndex) {
      this.prevViewportStartIndex = viewportStartIndex;
      return;
    }

    const shift: number = targetWindowStartIndex - this.prevWindowStartIndex;
    const maxIndex: number = this.itemCount - 1;
    const invalidIndex: number = this.itemCount;
    this.rowGlobalIndices.modify(indices => {
      let didRecycle = false;

      if (Math.abs(shift) >= this.rowCount) {
        for (let i = 0; i < this.rowCount; i += 1) {
          const candidateIndex: number = targetWindowStartIndex + i;
          const nextIndex: number = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[i] === nextIndex) continue;
          indices[i] = nextIndex;
          didRecycle = true;
        }

        return didRecycle ? indices : indices;
      }

      if (shift > 0) {
        for (let i = 0; i < shift; i += 1) {
          let minRow = 0;
          let minVal: number = indices[0];

          for (let j = 1; j < this.rowCount; j += 1) {
            const value: number = indices[j];
            if (value < minVal) {
              minRow = j;
              minVal = value;
            }
          }

          const candidateIndex: number = targetWindowStartIndex + this.rowCount - shift + i;
          const nextIndex: number = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[minRow] === nextIndex) continue;
          indices[minRow] = nextIndex;
          didRecycle = true;
        }

        return didRecycle ? indices : indices;
      }

      if (shift < 0) {
        const recycleCount: number = -shift;

        for (let i = 0; i < recycleCount; i += 1) {
          let maxRow = 0;
          let maxVal: number = indices[0];

          for (let j = 1; j < this.rowCount; j += 1) {
            const value: number = indices[j];
            if (value > maxVal) {
              maxVal = value;
              maxRow = j;
            }
          }

          const candidateIndex: number = targetWindowStartIndex + i;
          const nextIndex: number = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
          if (indices[maxRow] === nextIndex) continue;
          indices[maxRow] = nextIndex;
          didRecycle = true;
        }
      }

      return indices;
    });

    this.prevViewportStartIndex = viewportStartIndex;
    this.prevWindowStartIndex = targetWindowStartIndex;
  }

  setScrollOffset(offset: number): void {
    this.scrollViewOffset.value = offset;
    this.recycleRows();
  }

  private findIndexForPrefixAtLeast(target: number): number {
    if (this.length === 0) {
      return 0;
    }

    if (target <= 0) {
      return 0;
    }

    const total: number = this.totalSize.value;
    if (target >= total) {
      return this.length - 1;
    }

    let index = 0;
    let bit = 1;
    while (bit <= this.length) {
      bit <<= 1;
    }
    bit >>= 1;

    let remaining: number = target;
    while (bit !== 0) {
      const next: number = index + bit;
      if (next <= this.length && this.fenwicks[next] < remaining) {
        remaining -= this.fenwicks[next];
        index = next;
      }
      bit >>= 1;
    }

    return index;
  }

  private getMaxOffset(): number {
    const maxOffset: number = this.totalSize.value + this.scrollPaddingStart + this.scrollPaddingEnd - this.listSize;
    return maxOffset > 0 ? maxOffset : 0;
  }

  private getRowGapSize(rowIndex: number, rowCountOverride?: number): number {
    const rowCount: number = rowCountOverride ?? this.length;
    if (rowCount <= 1) {
      return 0;
    }

    if (this.isInverted) {
      return rowIndex > 0 ? this.gap : 0;
    }

    return rowIndex < rowCount - 1 ? this.gap : 0;
  }

  private getTargetWindowStartIndex(viewportStartIndex: number): number {
    const maxWindowStartIndex: number = Math.max(0, this.itemCount - this.rowCount);
    if (!this.isInverted) {
      return clamp(viewportStartIndex - this.bufferAbove, 0, maxWindowStartIndex);
    }

    const visibleRowCount: number = Math.max(0, this.rowCount - this.bufferAbove - this.bufferBelow);
    const visibleSpan: number = visibleRowCount > 0 ? visibleRowCount - 1 : 0;
    const targetStartIndex: number = viewportStartIndex - visibleSpan - this.bufferBelow;
    return clamp(targetStartIndex, 0, maxWindowStartIndex);
  }

  private invalidateCache(fromIndex: number): void {
    if (fromIndex < this.dirtyFromIndex) {
      this.dirtyFromIndex = fromIndex;
    }
  }

  private update(i: number, delta: number): void {
    let index: number = i + 1;
    while (index <= this.length) {
      this.fenwicks[index] += delta;
      index += index & -index;
    }
    this.invalidateCache(i);
  }

  private writeWindowIndices(targetWindowStartIndex: number): void {
    const maxIndex: number = this.itemCount - 1;
    const invalidIndex: number = this.itemCount;
    this.rowGlobalIndices.modify(indices => {
      for (let i = 0; i < this.rowCount; i += 1) {
        const candidateIndex: number = targetWindowStartIndex + i;
        indices[i] = candidateIndex <= maxIndex ? candidateIndex : invalidIndex;
      }

      return indices;
    });
  }
}

// ============ AnimatedList Components ======================================== //

const typedMemo: <T>(c: T) => T = memo;

export const AnimatedList = typedMemo(function AnimatedList<T>({
  columnGap,
  contentContainerStyle,
  data,
  estimatedItemSize,
  gap,
  getItemSize,
  horizontal,
  inverted,
  itemMetricsVersion,
  itemSizes,
  itemSize,
  itemWidth,
  keyExtractor,
  listHeight,
  listWidth,
  maintainVisibleContentIndices,
  maintainVisibleContentPosition,
  maintainScrollAtEdge,
  numColumns,
  onScroll,
  renderItem,
  rowBuffer,
  scrollIndicatorInsets,
  scrollOffset: scrollOffsetProp,
  style,
}: AnimatedListProps<T>): React.ReactElement {
  const isHorizontal: boolean = horizontal === true;
  const isInverted: boolean = inverted === true;
  const resolvedNumColumns: number = Math.max(1, numColumns ?? DEFAULT_NUM_COLUMNS);
  const resolvedColumnGap: number = columnGap ?? DEFAULT_COLUMN_GAP;
  const resolvedRowBuffer: RowBufferConfig = rowBuffer ?? ROW_BUFFER;
  const estimatedRowSize: number = itemSize ?? estimatedItemSize;
  const mainAxisSize: number = isHorizontal ? listWidth : listHeight;
  const crossAxisSize: number = isHorizontal ? listHeight : listWidth;

  const scrollPadding: ScrollPadding = useMemo(
    (): ScrollPadding => resolveScrollPadding({ contentContainerStyle, isHorizontal }),
    [contentContainerStyle, isHorizontal]
  );

  const scrollPaddingStart: number = scrollPadding.start;
  const scrollPaddingEnd: number = scrollPadding.end;

  const rowWindowConfig: RowWindowConfig = useMemo(
    (): RowWindowConfig =>
      getRowWindowConfig({
        gap,
        listSize: mainAxisSize,
        rowBuffer: resolvedRowBuffer,
        rowSize: estimatedRowSize,
      }),
    [estimatedRowSize, gap, mainAxisSize, resolvedRowBuffer]
  );

  const rowCount: number = rowWindowConfig.rowCount;
  const requiredRows: number[] = useMemo((): number[] => createIndexArray(rowCount), [rowCount]);
  const columnIndices: number[] = useMemo((): number[] => createIndexArray(resolvedNumColumns), [resolvedNumColumns]);

  const rowGlobalIndices = useSharedValue<Uint32Array>(createIndexTypedArray(rowCount));
  const rowDataCount = useSharedValue<number>(0);
  const rowOffsets = useSharedValue<Float32Array>(new Float32Array(0));
  const scrollViewOffset = useSharedValue<number>(0);
  const totalSize = useSharedValue<number>(0);
  const lastHandledTotalSize = useSharedValue<number>(0);
  const pendingScrollTarget = useSharedValue<number>(-1);

  const didMountRef = useRef(false);
  const scrollViewRef = useAnimatedRef<Animated.ScrollView>();

  const maintainConfig: MaintainConfig = useMemo(
    (): MaintainConfig =>
      resolveMaintainConfig({
        maintainScrollAtEdge,
        maintainVisibleContentIndices,
        maintainVisibleContentPosition,
      }),
    [maintainScrollAtEdge, maintainVisibleContentIndices, maintainVisibleContentPosition]
  );

  const fenwickTree = useWorkletClass((): FenwickTree => {
    'worklet';
    const initialState = buildInitialTreeState({
      data: data.value,
      estimatedRowSize,
      gap,
      getItemSize,
      itemSizes: itemSizes?.value,
      isInverted,
      numColumns: resolvedNumColumns,
      rowCount,
    });

    rowGlobalIndices.value = initialState.rowGlobalIndices;
    rowDataCount.value = initialState.rowDataCount;
    rowOffsets.value = initialState.initialOffsets;
    totalSize.value = initialState.totalSize;
    lastHandledTotalSize.value = initialState.totalSize;

    const tree: FenwickTree = new FenwickTree({
      bufferAbove: rowWindowConfig.bufferAbove,
      bufferBelow: rowWindowConfig.bufferBelow,
      gap,
      isHorizontal,
      isInverted,
      itemCount: initialState.rowDataCount,
      listSize: mainAxisSize,
      maintainConfig,
      pendingScrollTarget,
      rowCount,
      rowDataCount,
      rowGlobalIndices,
      scrollPaddingEnd,
      scrollPaddingStart,
      scrollOffset: scrollViewOffset,
      scrollViewRef,
      totalSize,
    });

    tree.rebuild(initialState.rowDataCount, estimatedRowSize, initialState.initialSizes);

    return tree;
  });

  const handleScroll = useAnimatedScrollHandler(event => {
    const offset = isHorizontal ? event.contentOffset.x : event.contentOffset.y;
    fenwickTree.value?.setScrollOffset?.(offset);

    if (scrollOffsetProp) scrollOffsetProp.value = offset;
    if (onScroll) onScroll(event);
  });

  const rebuildTreeState = useCallback(() => {
    'worklet';
    const nextData: T[] = data.value;
    const metrics: RowMetrics = buildRowMetrics({
      data: nextData,
      estimatedRowSize,
      gap,
      getItemSize,
      itemSizes: itemSizes?.value,
      isInverted,
      numColumns: resolvedNumColumns,
    });
    rowDataCount.value = metrics.rowDataCount;

    const tree: FenwickTree | undefined = fenwickTree.value;
    if (!tree) return;

    tree.updateConfig({
      bufferAbove: rowWindowConfig.bufferAbove,
      bufferBelow: rowWindowConfig.bufferBelow,
      gap,
      isHorizontal,
      isInverted,
      listSize: mainAxisSize,
      maintainConfig,
      rowCount,
      scrollPaddingEnd,
      scrollPaddingStart,
    });
    tree.rebuild(metrics.rowDataCount, estimatedRowSize, metrics.sizes);
    rowOffsets.value = metrics.offsets;
  }, [
    data,
    estimatedRowSize,
    fenwickTree,
    gap,
    getItemSize,
    isHorizontal,
    isInverted,
    itemSizes,
    mainAxisSize,
    maintainConfig,
    resolvedNumColumns,
    rowCount,
    rowDataCount,
    rowOffsets,
    rowWindowConfig.bufferAbove,
    rowWindowConfig.bufferBelow,
    scrollPaddingEnd,
    scrollPaddingStart,
  ]);

  const captureMaintainAnchor = useCallback(
    (previousData: T[], prevScrollOffset: number, tree: FenwickTree): MaintainAnchor | null => {
      'worklet';
      const indicesConfig: MaintainIndicesConfig | null = maintainConfig.indices;
      if (indicesConfig) {
        return captureIndicesAnchor({
          align: indicesConfig.align,
          dataLength: previousData.length,
          indices: indicesConfig.indices,
          listSize: mainAxisSize,
          numColumns: resolvedNumColumns,
          scrollOffset: prevScrollOffset,
          strategy: indicesConfig.strategy,
          tree,
        });
      }

      const positionConfig: MaintainPositionConfig | null = maintainConfig.position;
      if (positionConfig) {
        return capturePositionAnchor<T>({
          anchorEdge: positionConfig.anchorEdge,
          data: previousData,
          keyExtractor,
          listSize: mainAxisSize,
          minIndexForVisible: positionConfig.minIndexForVisible,
          numColumns: resolvedNumColumns,
          scrollOffset: prevScrollOffset,
          tree,
        });
      }

      return null;
    },
    [keyExtractor, mainAxisSize, maintainConfig, resolvedNumColumns]
  );

  const getStickToEdgeOffset = useCallback(
    ({
      maxOffset,
      prevMaxOffset,
      prevScrollOffset,
    }: {
      maxOffset: number;
      prevMaxOffset: number;
      prevScrollOffset: number;
    }): number | null => {
      'worklet';
      const stickToEdgeConfig: MaintainScrollAtEdgeConfig | null = maintainConfig.stickToEdge;
      if (!stickToEdgeConfig) {
        return null;
      }

      return getStickToEdgeTarget({
        edge: stickToEdgeConfig.edge,
        isInverted,
        maxDistanceFromEdge: stickToEdgeConfig.maxDistanceFromEdge,
        maxOffset,
        mode: stickToEdgeConfig.mode,
        prevMaxOffset,
        prevScrollOffset,
      });
    },
    [isInverted, maintainConfig]
  );

  const applyMaintainAfterRebuild = useCallback(
    (currentData: T[], prevScrollOffset: number, prevMaxOffset: number, tree: FenwickTree, anchor: MaintainAnchor | null): void => {
      'worklet';
      const maxOffset: number = getMaxScrollOffset({
        listSize: mainAxisSize,
        scrollPaddingEnd,
        scrollPaddingStart,
        totalSize: totalSize.value,
      });
      const stickToEdgeOffset: number | null = getStickToEdgeOffset({
        maxOffset,
        prevMaxOffset,
        prevScrollOffset,
      });
      if (stickToEdgeOffset !== null) {
        scrollToOffset({
          isHorizontal,
          offset: stickToEdgeOffset,
          scrollViewRef,
        });
        return;
      }

      if (anchor) {
        const anchorOffset: number | null = getMaintainAnchorOffset({
          anchor,
          data: currentData,
          keyExtractor,
          maxOffset,
          numColumns: resolvedNumColumns,
          tree,
        });
        if (anchorOffset !== null) {
          scrollToOffset({ isHorizontal, offset: anchorOffset, scrollViewRef });
        }
      }
    },
    [
      getStickToEdgeOffset,
      isHorizontal,
      keyExtractor,
      mainAxisSize,
      resolvedNumColumns,
      scrollPaddingEnd,
      scrollPaddingStart,
      totalSize,
      scrollViewRef,
    ]
  );

  const handleMetricsChange = useCallback((): void => {
    'worklet';
    const tree: FenwickTree | undefined = fenwickTree.value;
    if (!tree) return;

    const currentData: T[] = data.value;
    const prevScrollOffset: number = scrollViewOffset.value;
    const prevMaxOffset: number = getMaxScrollOffset({
      listSize: mainAxisSize,
      scrollPaddingEnd,
      scrollPaddingStart,
      totalSize: lastHandledTotalSize.value,
    });
    const anchor: MaintainAnchor | null = captureMaintainAnchor(currentData, prevScrollOffset, tree);

    rebuildTreeState();
    applyMaintainAfterRebuild(currentData, prevScrollOffset, prevMaxOffset, tree, anchor);
    lastHandledTotalSize.value = totalSize.value;
  }, [
    applyMaintainAfterRebuild,
    captureMaintainAnchor,
    data,
    fenwickTree,
    lastHandledTotalSize,
    mainAxisSize,
    rebuildTreeState,
    scrollPaddingEnd,
    scrollPaddingStart,
    scrollViewOffset,
    totalSize,
  ]);

  const handleDataChange = useCallback(
    ({
      currentData,
      previousData,
      prevMaxOffset,
      prevScrollOffset,
      tree,
    }: {
      currentData: T[];
      previousData: T[];
      prevMaxOffset: number;
      prevScrollOffset: number;
      tree: FenwickTree;
    }): void => {
      'worklet';
      const anchor: MaintainAnchor | null = captureMaintainAnchor(previousData, prevScrollOffset, tree);

      rebuildTreeState();
      applyMaintainAfterRebuild(currentData, prevScrollOffset, prevMaxOffset, tree, anchor);
      lastHandledTotalSize.value = totalSize.value;
    },
    [applyMaintainAfterRebuild, captureMaintainAnchor, lastHandledTotalSize, rebuildTreeState, totalSize]
  );

  useAnimatedReaction(
    (): T[] => data.value,
    (current: T[], previous: T[] | null) => {
      if (!previous) {
        lastHandledTotalSize.value = totalSize.value;
        return;
      }

      const tree: FenwickTree | undefined = fenwickTree.value;
      if (!tree) {
        lastHandledTotalSize.value = totalSize.value;
        return;
      }

      const currentLength: number = current.length;
      const previousLength: number = previous.length;
      const dataChanged: boolean = current !== previous || currentLength !== previousLength;
      const prevScrollOffset: number = scrollViewOffset.value;
      const prevMaxOffset: number = getMaxScrollOffset({
        listSize: mainAxisSize,
        scrollPaddingEnd,
        scrollPaddingStart,
        totalSize: lastHandledTotalSize.value,
      });

      if (!dataChanged) {
        return;
      }

      handleDataChange({
        currentData: current,
        previousData: previous,
        prevMaxOffset,
        prevScrollOffset,
        tree,
      });
    },
    []
  );

  useAnimatedReaction(
    () => itemMetricsVersion?.value,
    (currentVersion, previousVersion) => {
      if (currentVersion === undefined) return;
      if (previousVersion !== null && currentVersion === previousVersion) return;
      if (previousVersion === null && currentVersion === 0) return;
      handleMetricsChange();
    },
    []
  );

  useEffect((): void => {
    if (!didMountRef.current) {
      didMountRef.current = true;
      return;
    }

    runOnUI(rebuildTreeState)();
  }, [rebuildTreeState]);

  const contentSizeStyle = useAnimatedStyle(() => {
    const rowCountValue: number = rowDataCount.value;
    const estimatedSize: number = rowCountValue > 0 ? rowCountValue * (estimatedRowSize + gap) - gap : 0;
    const mainSize: number = totalSize.value || estimatedSize;
    return isHorizontal ? { height: crossAxisSize, width: mainSize } : { height: mainSize, width: crossAxisSize };
  }, [crossAxisSize, estimatedRowSize, gap, isHorizontal]);

  const handleContentSizeChange = useCallback((): void => {
    runOnUI(() => {
      'worklet';
      fenwickTree.value?.applyPendingScroll?.();
    })();
  }, [fenwickTree]);

  return (
    <View style={{ height: listHeight, position: 'relative', width: listWidth }}>
      <Animated.ScrollView
        contentContainerStyle={contentContainerStyle}
        horizontal={isHorizontal}
        onContentSizeChange={handleContentSizeChange}
        onScroll={handleScroll}
        ref={scrollViewRef}
        scrollEventThrottle={8}
        scrollIndicatorInsets={scrollIndicatorInsets}
        style={[style, { height: listHeight, overflow: 'hidden', width: listWidth }]}
      >
        <Animated.View style={contentSizeStyle}>
          {requiredRows.map((localIndex: number) => (
            <RecycledRow
              columnGap={resolvedColumnGap}
              columnIndices={columnIndices}
              crossAxisSize={crossAxisSize}
              data={data}
              fenwickTree={fenwickTree}
              gap={gap}
              isHorizontal={isHorizontal}
              isInverted={isInverted}
              itemWidth={itemWidth}
              key={localIndex}
              localIndex={localIndex}
              numColumns={resolvedNumColumns}
              renderItem={renderItem}
              rowDataCount={rowDataCount}
              rowIndices={rowGlobalIndices}
              rowOffsets={rowOffsets}
              scrollViewRef={scrollViewRef}
              totalSize={totalSize}
              {...(itemSizes ? { estimatedItemSize, itemSizes } : getItemSize ? { estimatedItemSize, getItemSize } : { itemSize })}
            />
          ))}
        </Animated.View>
      </Animated.ScrollView>
    </View>
  );
});

function RecycledRow<T>({
  columnGap,
  columnIndices,
  crossAxisSize,
  data,
  estimatedItemSize,
  fenwickTree,
  gap,
  isHorizontal,
  isInverted,
  getItemSize,
  itemSizes,
  itemSize,
  itemWidth,
  localIndex,
  numColumns,
  renderItem,
  rowDataCount,
  rowIndices,
  rowOffsets,
  scrollViewRef,
  totalSize,
}: {
  columnGap: number;
  columnIndices: number[];
  crossAxisSize: number;
  data: SharedValue<T[]>;
  fenwickTree: SharedValue<FenwickTree | undefined>;
  gap: number;
  isHorizontal: boolean;
  isInverted: boolean;
  itemWidth: number;
  localIndex: number;
  numColumns: number;
  renderItem: (props: RenderItemProps<T>) => React.ReactNode;
  rowDataCount: SharedValue<number>;
  rowIndices: SharedValue<Uint32Array>;
  rowOffsets: SharedValue<Float32Array>;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
  totalSize: SharedValue<number>;
} & ItemSizeConfig<T>): React.ReactElement {
  const resolvedItemSize: number = itemSize ?? estimatedItemSize;
  const itemCrossSize: number = itemWidth;

  const rowIndex = useDerivedValue(() => {
    const indices: Uint32Array = rowIndices.value;
    const index: number = indices[localIndex] ?? rowDataCount.value;
    return index;
  });

  const isRowActive = useDerivedValue(() => {
    const dataRowCount: number = rowDataCount.value;
    return dataRowCount > 0 && rowIndex.value < dataRowCount;
  });

  const rowSize = useDerivedValue(() => {
    if (!isRowActive.value) return 0;

    if (!getItemSize && !itemSizes) return resolvedItemSize;

    const dataLength: number = data.value.length;
    const startIndex: number = rowIndex.value * numColumns;
    const endIndex: number = Math.min(startIndex + numColumns, dataLength);
    let maxSize = 0;

    for (let i: number = startIndex; i < endIndex; i += 1) {
      let itemSizeValue = 0;
      if (itemSizes) itemSizeValue = itemSizes.value[i] ?? 0;
      else if (getItemSize) itemSizeValue = getItemSize(i, data.value[i]);

      if (itemSizeValue > maxSize) {
        maxSize = itemSizeValue;
      }
    }

    return maxSize;
  });

  const translateMain = useDerivedValue(() => {
    if (!isRowActive.value) return -9999;

    const offsets: Float32Array = rowOffsets.value;
    const rowIndexValue: number = rowIndex.value;
    const fallbackOffset: number =
      rowIndexValue >= 0 && rowIndexValue < offsets.length ? (offsets[rowIndexValue] ?? 0) : rowIndexValue * (resolvedItemSize + gap);

    if (!isInverted) return fallbackOffset;

    const nextOffset: number | undefined = rowIndexValue + 1 < offsets.length ? offsets[rowIndexValue + 1] : undefined;
    const gapSize: number = getRowGap({
      gap,
      isInverted,
      rowCount: rowDataCount.value,
      rowIndex: rowIndexValue,
    });

    const fallbackEnd: number = nextOffset ?? fallbackOffset + rowSize.value + gapSize;

    return totalSize.value - fallbackEnd;
  });

  const rowStyle = useAnimatedStyle(() => {
    const opacity: number = isRowActive.value ? 1 : 0;
    const mainSize: number = rowSize.value;
    const transform: ViewStyle['transform'] = isHorizontal ? [{ translateX: translateMain.value }] : [{ translateY: translateMain.value }];
    return isHorizontal ? { opacity, transform, width: mainSize } : { height: mainSize, opacity, transform };
  }, [isHorizontal]);

  const rowBaseStyle: ViewStyle = isHorizontal
    ? { height: crossAxisSize, position: 'absolute' }
    : { position: 'absolute', width: crossAxisSize };

  const rowContent: React.ReactNode[] = columnIndices.map((columnIndex: number) => (
    <RecycledCell
      columnGap={columnGap}
      columnIndex={columnIndex}
      data={data}
      fenwickTree={fenwickTree}
      isHorizontal={isHorizontal}
      itemCrossSize={itemCrossSize}
      key={columnIndex}
      numColumns={numColumns}
      renderItem={renderItem}
      rowIndex={rowIndex}
      scrollViewRef={scrollViewRef}
    />
  ));

  return <Animated.View style={[rowBaseStyle, rowStyle]}>{rowContent}</Animated.View>;
}

function RecycledCell<T>({
  columnGap,
  columnIndex,
  data,
  fenwickTree,
  isHorizontal,
  itemCrossSize,
  numColumns,
  renderItem,
  rowIndex,
  scrollViewRef,
}: {
  columnGap: number;
  columnIndex: number;
  data: SharedValue<T[]>;
  fenwickTree: SharedValue<FenwickTree | undefined>;
  isHorizontal: boolean;
  itemCrossSize: number;
  numColumns: number;
  renderItem: (props: RenderItemProps<T>) => React.ReactNode;
  rowIndex: DerivedValue<number>;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
}): React.ReactElement {
  const itemIndex = useDerivedValue(() => {
    const dataLength: number = data.value.length;
    const rowIndexValue: number = rowIndex.value;

    return getItemIndexForRow({
      columnIndex,
      dataLength,
      numColumns,
      rowIndex: rowIndexValue,
    });
  });

  const isActive = useDerivedValue(() => {
    const index: number = itemIndex.value;
    const dataLength: number = data.value.length;
    return index >= 0 && index < dataLength;
  });

  const cellOffset: number = columnIndex * (itemCrossSize + columnGap);
  const cellStyle = useAnimatedStyle(() => {
    const scale: number = isActive.value ? 1 : 0;
    return {
      opacity: isActive.value ? 1 : 0,
      transform: [{ scale }],
    };
  });

  const cellBaseStyle: ViewStyle = isHorizontal
    ? {
        height: itemCrossSize,
        left: 0,
        position: 'absolute',
        top: cellOffset,
        width: '100%',
      }
    : {
        height: '100%',
        left: cellOffset,
        position: 'absolute',
        top: 0,
        width: itemCrossSize,
      };

  return (
    <Animated.View style={[cellBaseStyle, cellStyle]}>
      {renderItem({
        columnIndex,
        data,
        fenwickTree,
        isActive,
        itemIndex,
        rowIndex,
        scrollViewRef,
      })}
    </Animated.View>
  );
}
