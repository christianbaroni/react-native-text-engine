import React, { ComponentProps, memo, useCallback, useMemo } from 'react';
import { type Insets, type NativeScrollEvent, type StyleProp, StyleSheet, View, type ViewStyle } from 'react-native';
import { useStableValue } from '@storesjs/stores';
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
import { runOnUISync } from 'react-native-worklets';
import { useRunOnce } from '../hooks/useRunOnce';
import { FenwickTree } from './FenwickTree';

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

type RowMetrics = {
  offsets: Float32Array;
  rowDataCount: number;
  sizes: Float32Array | undefined;
  totalSize: number;
};

export type ExactRowLayout = RowMetrics;

type ListFrame<T> = {
  data: T[];
  rowGlobalIndices: Uint32Array;
  rowLayout: RowMetrics;
};

type InitialListState<T> = {
  frame: ListFrame<T>;
  scrollOffset: number;
};

type PendingListFrame<T> = {
  frame: ListFrame<T>;
  scrollOffset: number;
  syncData: boolean;
};

type AnimatedListRuntimeConfig = {
  bufferAbove: number;
  bufferBelow: number;
  estimatedRowSize: number;
  gap: number;
  isInverted: boolean;
  listSize: number;
  numColumns: number;
  rowCount: number;
  scrollPaddingEnd: number;
  scrollPaddingStart: number;
};

type ScrollPadding = {
  end: number;
  start: number;
};

export type RenderItemProps<T> = {
  columnIndex: number;
  data: DerivedValue<T[]>;
  isActive: DerivedValue<boolean>;
  item: DerivedValue<T | undefined>;
  itemIndex: DerivedValue<number>;
  rowIndex: DerivedValue<number>;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
};

/**
 * UI-runtime bridge for publishing exact row geometry and matching data as one list transaction.
 */
export type ExactLayoutController<T> = {
  applyLayout: (snapshot: ExactLayoutSnapshot<T>) => void;
};

export type ExactLayoutSnapshot<T> = {
  data?: T[];
  rowLayout: ExactRowLayout;
};

type WorkletContextValue<T> = {
  __workletContextObject: true;
  current: T;
};

/**
 * Stable cross-runtime holder populated by `AnimatedList` after its UI-thread tree is ready.
 */
export type ExactLayoutControllerContext<T = unknown> = WorkletContextValue<ExactLayoutController<T> | undefined> & {
  pendingSnapshot?: ExactLayoutSnapshot<T>;
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
  exactLayoutController?: ExactLayoutControllerContext<T>;
  gap: number;
  /**
   * Starts at the data end.
   * Use with `maintainScrollAtEdge` when the list should also stay pinned.
   */
  initialScrollToEnd?: boolean;
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
const ROW_BUFFER: RowBufferConfig = 8;

function clamp(value: number, lower: number, upper: number): number {
  'worklet';
  return Math.min(Math.max(value, lower), upper);
}

function didRuntimeConfigChange(current: AnimatedListRuntimeConfig, previous: AnimatedListRuntimeConfig | null): boolean {
  'worklet';
  if (!previous) return false;

  return (
    current.bufferAbove !== previous.bufferAbove ||
    current.bufferBelow !== previous.bufferBelow ||
    current.estimatedRowSize !== previous.estimatedRowSize ||
    current.gap !== previous.gap ||
    current.isInverted !== previous.isInverted ||
    current.listSize !== previous.listSize ||
    current.numColumns !== previous.numColumns ||
    current.rowCount !== previous.rowCount ||
    current.scrollPaddingEnd !== previous.scrollPaddingEnd ||
    current.scrollPaddingStart !== previous.scrollPaddingStart
  );
}

function updateTreeConfig(tree: FenwickTree, config: AnimatedListRuntimeConfig): void {
  'worklet';
  tree.updateConfig({
    bufferAbove: config.bufferAbove,
    bufferBelow: config.bufferBelow,
    gap: config.gap,
    isInverted: config.isInverted,
    listSize: config.listSize,
    rowCount: config.rowCount,
    scrollPaddingEnd: config.scrollPaddingEnd,
    scrollPaddingStart: config.scrollPaddingStart,
  });
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

function getRowEndOffset({
  offsets,
  rowDataCount,
  rowIndex,
  totalSize,
}: {
  offsets: Float32Array;
  rowDataCount: number;
  rowIndex: number;
  totalSize: number;
}): number {
  'worklet';
  if (rowIndex + 1 < rowDataCount) {
    return offsets[rowIndex + 1] ?? totalSize;
  }

  return totalSize;
}

function getRowMainSize({
  gap,
  isInverted,
  offsets,
  rowDataCount,
  rowIndex,
  totalSize,
}: {
  gap: number;
  isInverted: boolean;
  offsets: Float32Array;
  rowDataCount: number;
  rowIndex: number;
  totalSize: number;
}): number {
  'worklet';
  if (rowIndex < 0 || rowIndex >= rowDataCount) {
    return 0;
  }

  const rowStart: number = offsets[rowIndex] ?? 0;
  const rowEnd: number = getRowEndOffset({
    offsets,
    rowDataCount,
    rowIndex,
    totalSize,
  });
  const gapSize: number = getRowGap({
    gap,
    isInverted,
    rowCount: rowDataCount,
    rowIndex,
  });

  return Math.max(0, rowEnd - rowStart - gapSize);
}

function buildRowSizesFromOffsets({
  offsets,
  rowDataCount,
  totalSize,
}: {
  offsets: Float32Array;
  rowDataCount: number;
  totalSize: number;
}): Float32Array {
  'worklet';
  const sizes = new Float32Array(rowDataCount);

  for (let rowIndex = 0; rowIndex < rowDataCount; rowIndex += 1) {
    const rowStart = offsets[rowIndex] ?? 0;
    const rowEnd = getRowEndOffset({
      offsets,
      rowDataCount,
      rowIndex,
      totalSize,
    });
    sizes[rowIndex] = Math.max(0, rowEnd - rowStart);
  }

  return sizes;
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
      const gapSize: number = getRowGap({ gap, isInverted, rowCount: rowDataCount, rowIndex });
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

    const gapSize: number = getRowGap({ gap, isInverted, rowCount: rowDataCount, rowIndex });
    const rowSize: number = maxSize + gapSize;
    sizes[rowIndex] = rowSize;
    sum += rowSize;
  }

  return { offsets, rowDataCount, sizes, totalSize: sum };
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

function buildInitialListState<T>({
  bufferAbove,
  bufferBelow,
  data,
  estimatedRowSize,
  gap,
  getItemSize,
  initialScrollToEnd,
  itemSizes,
  isInverted,
  listSize,
  numColumns,
  rowCount,
  scrollPaddingEnd,
  scrollPaddingStart,
}: {
  bufferAbove: number;
  bufferBelow: number;
  data: T[];
  estimatedRowSize: number;
  gap: number;
  getItemSize: ((index: number, item: T) => number) | undefined;
  initialScrollToEnd: boolean;
  itemSizes: Float32Array | undefined;
  isInverted: boolean;
  listSize: number;
  numColumns: number;
  rowCount: number;
  scrollPaddingEnd: number;
  scrollPaddingStart: number;
}): InitialListState<T> {
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
  const scrollOffset: number = initialScrollToEnd
    ? getMaxScrollOffset({
        listSize,
        scrollPaddingEnd,
        scrollPaddingStart,
        totalSize: metrics.totalSize,
      })
    : 0;
  const tree = new FenwickTree({
    bufferAbove,
    bufferBelow,
    gap,
    isInverted,
    itemCount: metrics.rowDataCount,
    listSize,
    rowCount,
    scrollPaddingEnd,
    scrollPaddingStart,
  });
  const rowGlobalIndices: Uint32Array = tree.rebuild(metrics.rowDataCount, estimatedRowSize, scrollOffset, metrics.sizes);

  return {
    frame: {
      data,
      rowGlobalIndices,
      rowLayout: {
        offsets: metrics.offsets,
        rowDataCount: metrics.rowDataCount,
        sizes: metrics.sizes,
        totalSize: tree.getTotalSize(),
      },
    },
    scrollOffset,
  };
}

function replaceFrameIndices<T>(frame: ListFrame<T>, rowGlobalIndices: Uint32Array): ListFrame<T> {
  'worklet';
  return {
    data: frame.data,
    rowGlobalIndices,
    rowLayout: frame.rowLayout,
  };
}

function getStyleNumber(style: object, key: string): number | undefined {
  const value: unknown = Reflect.get(style, key);
  return typeof value === 'number' ? value : undefined;
}

const ZERO_SCROLL_PADDING: ScrollPadding = { end: 0, start: 0 };

function resolveScrollPadding({
  contentContainerStyle,
  isHorizontal,
}: {
  contentContainerStyle: AnimatedScrollViewProps['contentContainerStyle'] | undefined;
  isHorizontal: boolean;
}): ScrollPadding {
  const flattened: unknown = StyleSheet.flatten<StyleProp<object>>(contentContainerStyle);
  if (!flattened || typeof flattened !== 'object') {
    return ZERO_SCROLL_PADDING;
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
  if (anchorEdge === 'end') return tree.getRowLayoutEndOffset(rowIndex);
  if (anchorEdge === 'start') return tree.getRowLayoutStartOffset(rowIndex);

  const rowStart: number = tree.getRowLayoutStartOffset(rowIndex);
  const rowEnd: number = tree.getRowLayoutEndOffset(rowIndex);

  return rowStart + (rowEnd - rowStart) / 2;
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
  if (item === undefined) {
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

  const anchorRowIndex: number = getRowIndexFromItemIndex({ index: anchorIndex, numColumns });
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
}): boolean {
  'worklet';
  if (!scrollViewRef()) return false;

  const xOffset: number = isHorizontal ? offset : 0;
  const yOffset: number = isHorizontal ? 0 : offset;
  scrollTo(scrollViewRef, xOffset, yOffset, false);
  return true;
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

  const rowIndex: number = getRowIndexFromItemIndex({ index: targetIndex, numColumns });
  const rowEdgeOffset: number = getRowEdgeOffset({ anchorEdge: anchor.anchorEdge, rowIndex, tree });
  const nextOffset: number = clamp(rowEdgeOffset - anchor.anchorOffset, 0, maxOffset);

  return nextOffset;
}

// ============ AnimatedList Components ======================================== //

const typedMemo: <T>(c: T) => T = memo;

export const AnimatedList = typedMemo(function AnimatedList<T>({
  columnGap,
  contentContainerStyle,
  data,
  estimatedItemSize,
  exactLayoutController,
  gap,
  getItemSize,
  horizontal,
  initialScrollToEnd,
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
  const initialListState: InitialListState<T> = useStableValue(
    (): InitialListState<T> =>
      buildInitialListState({
        bufferAbove: rowWindowConfig.bufferAbove,
        bufferBelow: rowWindowConfig.bufferBelow,
        data: data.value,
        estimatedRowSize,
        gap,
        getItemSize,
        initialScrollToEnd: initialScrollToEnd === true,
        itemSizes: itemSizes?.value,
        isInverted,
        listSize: mainAxisSize,
        numColumns: resolvedNumColumns,
        rowCount,
        scrollPaddingEnd,
        scrollPaddingStart,
      })
  );

  const initialFrame: ListFrame<T> = initialListState.frame;
  const initialScrollOffset: number = initialListState.scrollOffset;
  const initialContentOffset = useStableValue(() => ({
    x: isHorizontal ? initialScrollOffset : 0,
    y: isHorizontal ? 0 : initialScrollOffset,
  }));

  const listFrame = useSharedValue<ListFrame<T>>(initialFrame);
  const pendingListFrame = useSharedValue<PendingListFrame<T> | null>(null);
  const scrollViewOffset = useSharedValue<number>(initialScrollOffset);
  const contentSize = useSharedValue<number>(initialFrame.rowLayout.totalSize);
  const lastHandledTotalSize = useSharedValue<number>(initialFrame.rowLayout.totalSize);
  const initialScrollPending = useSharedValue<boolean>(initialScrollToEnd === true && initialFrame.rowLayout.rowDataCount === 0);

  const rowGlobalIndices = useDerivedValue(() => listFrame.value.rowGlobalIndices);
  const rowLayout = useDerivedValue(() => listFrame.value.rowLayout);
  const renderData = useDerivedValue(() => listFrame.value.data);

  const scrollViewRef = useAnimatedRef<Animated.ScrollView>();
  const fenwickTree = useStableValue<WorkletContextValue<FenwickTree | undefined>>(() => ({
    __workletContextObject: true,
    current: undefined,
  }));

  const maintainConfig: MaintainConfig = useMemo(
    (): MaintainConfig =>
      resolveMaintainConfig({
        maintainScrollAtEdge,
        maintainVisibleContentIndices,
        maintainVisibleContentPosition,
      }),
    [maintainScrollAtEdge, maintainVisibleContentIndices, maintainVisibleContentPosition]
  );
  const maintainConfigValue = useDerivedValue(() => maintainConfig);
  const runtimeConfig = useDerivedValue<AnimatedListRuntimeConfig>(() => ({
    bufferAbove: rowWindowConfig.bufferAbove,
    bufferBelow: rowWindowConfig.bufferBelow,
    estimatedRowSize,
    gap,
    isInverted,
    listSize: mainAxisSize,
    numColumns: resolvedNumColumns,
    rowCount,
    scrollPaddingEnd,
    scrollPaddingStart,
  }));

  const handleScroll = useAnimatedScrollHandler(event => {
    const offset = isHorizontal ? event.contentOffset.x : event.contentOffset.y;
    const nextIndices = fenwickTree.current?.setScrollOffset?.(offset);

    scrollViewOffset.value = offset;
    if (nextIndices) {
      const frame: ListFrame<T> = listFrame.value;
      listFrame.value = replaceFrameIndices(frame, nextIndices);
    }
    if (scrollOffsetProp) scrollOffsetProp.value = offset;
    if (onScroll) onScroll(event);
  });

  const requestProgrammaticScroll = useCallback(
    (offset: number): void => {
      'worklet';
      scrollViewOffset.value = offset;
      if (scrollOffsetProp) scrollOffsetProp.value = offset;
      const didScroll: boolean = scrollToOffset({ isHorizontal, offset, scrollViewRef });
      if (didScroll && initialScrollPending.value && listFrame.value.rowLayout.rowDataCount > 0) initialScrollPending.value = false;
    },
    [initialScrollPending, isHorizontal, listFrame, scrollOffsetProp, scrollViewOffset, scrollViewRef]
  );

  const applyCurrentScrollOffset = useCallback(
    (nativeContentSize?: number): void => {
      'worklet';
      const pending: PendingListFrame<T> | null = pendingListFrame.value;
      if (pending) {
        const frame: ListFrame<T> = pending.frame;
        if (nativeContentSize !== undefined && nativeContentSize + 0.5 < frame.rowLayout.totalSize) return;

        const config: AnimatedListRuntimeConfig = runtimeConfig.value;
        const tree: FenwickTree =
          fenwickTree.current ??
          new FenwickTree({
            bufferAbove: config.bufferAbove,
            bufferBelow: config.bufferBelow,
            gap: config.gap,
            isInverted: config.isInverted,
            itemCount: frame.rowLayout.rowDataCount,
            listSize: config.listSize,
            rowCount: config.rowCount,
            scrollPaddingEnd: config.scrollPaddingEnd,
            scrollPaddingStart: config.scrollPaddingStart,
          });
        updateTreeConfig(tree, config);

        const nextSizes: Float32Array = frame.rowLayout.sizes ?? buildRowSizesFromOffsets(frame.rowLayout);
        const nextIndices: Uint32Array = tree.rebuild(
          frame.rowLayout.rowDataCount,
          config.estimatedRowSize,
          pending.scrollOffset,
          nextSizes
        );
        const frameToPublish: ListFrame<T> = replaceFrameIndices(frame, nextIndices);

        fenwickTree.current = tree;
        pendingListFrame.value = null;
        listFrame.value = frameToPublish;
        if (pending.syncData) data.value = frame.data;
        contentSize.value = frameToPublish.rowLayout.totalSize;
        lastHandledTotalSize.value = frameToPublish.rowLayout.totalSize;
        requestProgrammaticScroll(pending.scrollOffset);
        return;
      }

      const offset: number = scrollViewOffset.value;
      const nextIndices = fenwickTree.current?.setScrollOffset?.(offset);
      if (nextIndices) {
        const frame: ListFrame<T> = listFrame.value;
        listFrame.value = replaceFrameIndices(frame, nextIndices);
      }

      requestProgrammaticScroll(offset);
    },
    [
      contentSize,
      data,
      fenwickTree,
      lastHandledTotalSize,
      listFrame,
      pendingListFrame,
      requestProgrammaticScroll,
      runtimeConfig,
      scrollViewOffset,
    ]
  );

  const rebuildTreeState = useCallback(
    (currentData: T[], offset: number): ListFrame<T> | null => {
      'worklet';
      const config: AnimatedListRuntimeConfig = runtimeConfig.value;
      const frame: ListFrame<T> = listFrame.value;
      const metrics: RowMetrics = exactLayoutController
        ? frame.rowLayout
        : buildRowMetrics({
            data: currentData,
            estimatedRowSize: config.estimatedRowSize,
            gap: config.gap,
            getItemSize,
            itemSizes: itemSizes?.value,
            isInverted: config.isInverted,
            numColumns: config.numColumns,
          });

      const tree: FenwickTree | undefined = fenwickTree.current;
      if (!tree) return null;

      updateTreeConfig(tree, config);

      const nextSizes = exactLayoutController ? buildRowSizesFromOffsets(metrics) : metrics.sizes;
      const nextIndices = tree.rebuild(metrics.rowDataCount, config.estimatedRowSize, offset, nextSizes);

      return {
        data: currentData,
        rowGlobalIndices: nextIndices,
        rowLayout: {
          offsets: metrics.offsets,
          rowDataCount: metrics.rowDataCount,
          sizes: nextSizes,
          totalSize: tree.getTotalSize(),
        },
      };
    },
    [fenwickTree, getItemSize, itemSizes, exactLayoutController, listFrame, runtimeConfig]
  );

  const captureMaintainAnchor = useCallback(
    (previousData: T[], prevScrollOffset: number, tree: FenwickTree): MaintainAnchor | null => {
      'worklet';
      const config: AnimatedListRuntimeConfig = runtimeConfig.value;
      const currentMaintainConfig: MaintainConfig = maintainConfigValue.value;
      const indicesConfig = currentMaintainConfig.indices;
      if (indicesConfig) {
        return captureIndicesAnchor({
          align: indicesConfig.align,
          dataLength: previousData.length,
          indices: indicesConfig.indices,
          listSize: config.listSize,
          numColumns: config.numColumns,
          scrollOffset: prevScrollOffset,
          strategy: indicesConfig.strategy,
          tree,
        });
      }

      const positionConfig = currentMaintainConfig.position;
      if (positionConfig) {
        return capturePositionAnchor<T>({
          anchorEdge: positionConfig.anchorEdge,
          data: previousData,
          keyExtractor,
          listSize: config.listSize,
          minIndexForVisible: positionConfig.minIndexForVisible,
          numColumns: config.numColumns,
          scrollOffset: prevScrollOffset,
          tree,
        });
      }

      return null;
    },
    [keyExtractor, maintainConfigValue, runtimeConfig]
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
      const stickToEdgeConfig: MaintainScrollAtEdgeConfig | null = maintainConfigValue.value.stickToEdge;
      if (!stickToEdgeConfig) return null;

      return getStickToEdgeTarget({
        edge: stickToEdgeConfig.edge,
        isInverted: runtimeConfig.value.isInverted,
        maxDistanceFromEdge: stickToEdgeConfig.maxDistanceFromEdge,
        maxOffset,
        mode: stickToEdgeConfig.mode,
        prevMaxOffset,
        prevScrollOffset,
      });
    },
    [maintainConfigValue, runtimeConfig]
  );

  const getScrollTargetAfterRebuild = useCallback(
    ({
      anchor,
      currentData,
      maxOffset,
      prevMaxOffset,
      prevScrollOffset,
      rowDataCount,
      tree,
    }: {
      anchor: MaintainAnchor | null;
      currentData: T[];
      maxOffset: number;
      prevMaxOffset: number;
      prevScrollOffset: number;
      rowDataCount: number;
      tree: FenwickTree;
    }): number | null => {
      'worklet';
      const config: AnimatedListRuntimeConfig = runtimeConfig.value;

      const shouldApplyInitialScroll: boolean = initialScrollPending.value && rowDataCount > 0;
      if (shouldApplyInitialScroll) {
        return getScrollEdgeOffset({
          maxOffset,
          scrollEdge: resolveScrollEdgeToScrollEdge({ edge: 'end', isInverted: config.isInverted }),
        });
      }

      const stickToEdgeOffset: number | null = getStickToEdgeOffset({
        maxOffset,
        prevMaxOffset,
        prevScrollOffset,
      });

      if (stickToEdgeOffset !== null) return stickToEdgeOffset;

      if (anchor) {
        const anchorOffset: number | null = getMaintainAnchorOffset({
          anchor,
          data: currentData,
          keyExtractor,
          maxOffset,
          numColumns: config.numColumns,
          tree,
        });

        if (anchorOffset !== null) {
          return anchorOffset;
        }
      }

      return null;
    },
    [getStickToEdgeOffset, initialScrollPending, keyExtractor, runtimeConfig]
  );

  const handleMetricsChange = useCallback((): void => {
    'worklet';
    const tree: FenwickTree | undefined = fenwickTree.current;
    if (!tree) return;

    const config: AnimatedListRuntimeConfig = runtimeConfig.value;
    const currentData: T[] = exactLayoutController ? listFrame.value.data : data.value;
    const prevScrollOffset: number = scrollViewOffset.value;
    const anchor: MaintainAnchor | null = captureMaintainAnchor(currentData, prevScrollOffset, tree);
    const prevMaxOffset: number = getMaxScrollOffset({
      listSize: config.listSize,
      scrollPaddingEnd: config.scrollPaddingEnd,
      scrollPaddingStart: config.scrollPaddingStart,
      totalSize: lastHandledTotalSize.value,
    });

    const nextFrame: ListFrame<T> | null = rebuildTreeState(currentData, prevScrollOffset);
    if (!nextFrame) return;

    const maxOffset: number = getMaxScrollOffset({
      listSize: config.listSize,
      scrollPaddingEnd: config.scrollPaddingEnd,
      scrollPaddingStart: config.scrollPaddingStart,
      totalSize: nextFrame.rowLayout.totalSize,
    });
    const scrollTarget: number | null = getScrollTargetAfterRebuild({
      anchor,
      currentData,
      maxOffset,
      prevMaxOffset,
      prevScrollOffset,
      rowDataCount: nextFrame.rowLayout.rowDataCount,
      tree,
    });
    let frameToPublish: ListFrame<T> = nextFrame;

    if (scrollTarget !== null) {
      const targetIndices = tree.setScrollOffset(scrollTarget);
      if (targetIndices) frameToPublish = replaceFrameIndices(nextFrame, targetIndices);
    }

    listFrame.value = frameToPublish;
    contentSize.value = frameToPublish.rowLayout.totalSize;
    if (scrollTarget !== null) requestProgrammaticScroll(scrollTarget);
    lastHandledTotalSize.value = frameToPublish.rowLayout.totalSize;
  }, [
    captureMaintainAnchor,
    contentSize,
    data,
    exactLayoutController,
    fenwickTree,
    getScrollTargetAfterRebuild,
    lastHandledTotalSize,
    listFrame,
    requestProgrammaticScroll,
    rebuildTreeState,
    runtimeConfig,
    scrollViewOffset,
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

      const config: AnimatedListRuntimeConfig = runtimeConfig.value;
      const nextFrame: ListFrame<T> | null = rebuildTreeState(currentData, prevScrollOffset);
      if (!nextFrame) return;

      const maxOffset: number = getMaxScrollOffset({
        listSize: config.listSize,
        scrollPaddingEnd: config.scrollPaddingEnd,
        scrollPaddingStart: config.scrollPaddingStart,
        totalSize: nextFrame.rowLayout.totalSize,
      });
      const scrollTarget: number | null = getScrollTargetAfterRebuild({
        anchor,
        currentData,
        maxOffset,
        prevMaxOffset,
        prevScrollOffset,
        rowDataCount: nextFrame.rowLayout.rowDataCount,
        tree,
      });
      let frameToPublish: ListFrame<T> = nextFrame;

      if (scrollTarget !== null) {
        const targetIndices = tree.setScrollOffset(scrollTarget);
        if (targetIndices) frameToPublish = replaceFrameIndices(nextFrame, targetIndices);
      }

      listFrame.value = frameToPublish;
      contentSize.value = frameToPublish.rowLayout.totalSize;
      if (scrollTarget !== null) requestProgrammaticScroll(scrollTarget);
      lastHandledTotalSize.value = frameToPublish.rowLayout.totalSize;
    },
    [
      captureMaintainAnchor,
      contentSize,
      getScrollTargetAfterRebuild,
      lastHandledTotalSize,
      listFrame,
      rebuildTreeState,
      requestProgrammaticScroll,
      runtimeConfig,
    ]
  );

  const applyExactLayoutTransaction = useCallback(
    (snapshot: ExactLayoutSnapshot<T>): void => {
      'worklet';
      const tree: FenwickTree | undefined = fenwickTree.current;
      if (!tree) return;

      const layout: ExactRowLayout = snapshot.rowLayout;
      const config: AnimatedListRuntimeConfig = runtimeConfig.value;
      const previousData: T[] = listFrame.value.data;
      const currentData: T[] = snapshot.data ?? previousData;
      const prevScrollOffset: number = scrollViewOffset.value;
      const prevMaxOffset: number = getMaxScrollOffset({
        listSize: config.listSize,
        scrollPaddingEnd: config.scrollPaddingEnd,
        scrollPaddingStart: config.scrollPaddingStart,
        totalSize: lastHandledTotalSize.value,
      });
      const anchor: MaintainAnchor | null = captureMaintainAnchor(previousData, prevScrollOffset, tree);
      const nextSizes: Float32Array = buildRowSizesFromOffsets(layout);
      const nextTree = new FenwickTree({
        bufferAbove: config.bufferAbove,
        bufferBelow: config.bufferBelow,
        gap: config.gap,
        isInverted: config.isInverted,
        itemCount: layout.rowDataCount,
        listSize: config.listSize,
        rowCount: config.rowCount,
        scrollPaddingEnd: config.scrollPaddingEnd,
        scrollPaddingStart: config.scrollPaddingStart,
      });
      const nextIndices: Uint32Array = nextTree.rebuild(layout.rowDataCount, config.estimatedRowSize, prevScrollOffset, nextSizes);

      const nextFrame: ListFrame<T> = {
        data: currentData,
        rowGlobalIndices: nextIndices,
        rowLayout: {
          offsets: layout.offsets,
          rowDataCount: layout.rowDataCount,
          sizes: nextSizes,
          totalSize: nextTree.getTotalSize(),
        },
      };
      const maxOffset: number = getMaxScrollOffset({
        listSize: config.listSize,
        scrollPaddingEnd: config.scrollPaddingEnd,
        scrollPaddingStart: config.scrollPaddingStart,
        totalSize: nextFrame.rowLayout.totalSize,
      });
      const scrollTarget: number | null = getScrollTargetAfterRebuild({
        anchor,
        currentData,
        maxOffset,
        prevMaxOffset,
        prevScrollOffset,
        rowDataCount: nextFrame.rowLayout.rowDataCount,
        tree: nextTree,
      });

      if (scrollTarget !== null && scrollTarget > prevMaxOffset) {
        pendingListFrame.value = {
          frame: nextFrame,
          scrollOffset: scrollTarget,
          syncData: snapshot.data !== undefined,
        };
        contentSize.value = nextFrame.rowLayout.totalSize;
        return;
      }

      let frameToPublish: ListFrame<T> = nextFrame;

      if (scrollTarget !== null) {
        const targetIndices = nextTree.setScrollOffset(scrollTarget);
        if (targetIndices) frameToPublish = replaceFrameIndices(nextFrame, targetIndices);
      }

      fenwickTree.current = nextTree;
      listFrame.value = frameToPublish;
      if (snapshot.data !== undefined) data.value = currentData;
      contentSize.value = frameToPublish.rowLayout.totalSize;
      if (scrollTarget !== null) requestProgrammaticScroll(scrollTarget);
      lastHandledTotalSize.value = frameToPublish.rowLayout.totalSize;
    },
    [
      captureMaintainAnchor,
      contentSize,
      data,
      fenwickTree,
      getScrollTargetAfterRebuild,
      lastHandledTotalSize,
      listFrame,
      pendingListFrame,
      requestProgrammaticScroll,
      runtimeConfig,
      scrollViewOffset,
    ]
  );

  useRunOnce(() => {
    runOnUISync(
      (treeContext, controllerContext, applyLayout, config) => {
        const tree = new FenwickTree(config);
        tree.rebuild(config.initialRowDataCount, config.estimatedRowSize, config.initialScrollOffset, config.initialSizes);
        treeContext.current = tree;

        if (controllerContext) {
          controllerContext.current = { applyLayout };
          const pendingSnapshot = controllerContext.pendingSnapshot;

          if (pendingSnapshot) {
            controllerContext.pendingSnapshot = undefined;
            applyLayout(pendingSnapshot);
          }
        }
      },
      fenwickTree,
      exactLayoutController,
      applyExactLayoutTransaction,
      {
        bufferAbove: rowWindowConfig.bufferAbove,
        bufferBelow: rowWindowConfig.bufferBelow,
        estimatedRowSize,
        gap,
        initialRowDataCount: initialFrame.rowLayout.rowDataCount,
        initialScrollOffset,
        initialSizes: initialFrame.rowLayout.sizes,
        isInverted,
        itemCount: initialFrame.rowLayout.rowDataCount,
        listSize: mainAxisSize,
        rowCount,
        scrollPaddingEnd,
        scrollPaddingStart,
      }
    );
  });

  useAnimatedReaction(
    () => runtimeConfig.value,
    (currentConfig, previousConfig) => {
      if (!didRuntimeConfigChange(currentConfig, previousConfig)) return;

      handleMetricsChange();
    }
  );

  useAnimatedReaction(
    (): T[] => data.value,
    (current: T[], previous: T[] | null) => {
      if (exactLayoutController) return;

      if (!previous) {
        lastHandledTotalSize.value = rowLayout.value.totalSize;
        return;
      }

      const tree: FenwickTree | undefined = fenwickTree.current;
      if (!tree) {
        lastHandledTotalSize.value = rowLayout.value.totalSize;
        return;
      }

      const currentLength: number = current.length;
      const previousLength: number = previous.length;
      const dataChanged: boolean = current !== previous || currentLength !== previousLength;
      const config: AnimatedListRuntimeConfig = runtimeConfig.value;
      const prevScrollOffset: number = scrollViewOffset.value;
      const prevMaxOffset: number = getMaxScrollOffset({
        listSize: config.listSize,
        scrollPaddingEnd: config.scrollPaddingEnd,
        scrollPaddingStart: config.scrollPaddingStart,
        totalSize: lastHandledTotalSize.value,
      });

      if (!dataChanged) return;

      handleDataChange({
        currentData: current,
        previousData: previous,
        prevMaxOffset,
        prevScrollOffset,
        tree,
      });
    }
  );

  useAnimatedReaction(
    () => itemSizes?.value,
    (currentSizes, previousSizes) => {
      if (currentSizes === undefined || previousSizes === null || currentSizes === previousSizes) {
        return;
      }

      handleMetricsChange();
    }
  );

  useAnimatedReaction(
    () => itemMetricsVersion?.value,
    (currentVersion, previousVersion) => {
      if (currentVersion === undefined) return;
      if (previousVersion !== null && currentVersion === previousVersion) return;
      if (previousVersion === null && currentVersion === 0) return;

      handleMetricsChange();
    }
  );

  const contentSizeStyle = useAnimatedStyle(() => {
    const rowCountValue: number = rowLayout.value.rowDataCount;
    const estimatedSize: number = rowCountValue > 0 ? rowCountValue * (estimatedRowSize + gap) - gap : 0;
    const mainSize: number = contentSize.value || estimatedSize;

    if (isHorizontal) return { height: crossAxisSize, width: mainSize };

    return {
      height: mainSize,
      width: crossAxisSize,
    };
  });

  const handleContentSizeChange = useCallback(
    (width: number, height: number): void => {
      const nativeContentSize: number = isHorizontal ? width : height;
      runOnUISync(applyCurrentScrollOffset, nativeContentSize);
    },
    [applyCurrentScrollOffset, isHorizontal]
  );

  return (
    <View style={{ height: listHeight, position: 'relative', width: listWidth }}>
      <Animated.ScrollView
        contentOffset={initialContentOffset}
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
              data={renderData}
              gap={gap}
              isHorizontal={isHorizontal}
              isInverted={isInverted}
              itemWidth={itemWidth}
              key={localIndex}
              localIndex={localIndex}
              numColumns={resolvedNumColumns}
              renderItem={renderItem}
              rowIndices={rowGlobalIndices}
              rowLayout={rowLayout}
              scrollViewRef={scrollViewRef}
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
  gap,
  isHorizontal,
  isInverted,
  itemWidth,
  localIndex,
  numColumns,
  renderItem,
  rowIndices,
  rowLayout,
  scrollViewRef,
}: {
  columnGap: number;
  columnIndices: number[];
  crossAxisSize: number;
  data: DerivedValue<T[]>;
  gap: number;
  isHorizontal: boolean;
  isInverted: boolean;
  itemWidth: number;
  localIndex: number;
  numColumns: number;
  renderItem: (props: RenderItemProps<T>) => React.ReactNode;
  rowIndices: DerivedValue<Uint32Array>;
  rowLayout: DerivedValue<RowMetrics>;
  scrollViewRef: AnimatedRef<Animated.ScrollView>;
}): React.ReactElement {
  const itemCrossSize: number = itemWidth;

  const rowIndex = useDerivedValue(() => {
    const indices: Uint32Array = rowIndices.value;
    const index: number = indices[localIndex] ?? rowLayout.value.rowDataCount;
    return index;
  });

  const isRowActive = useDerivedValue(() => {
    const dataRowCount: number = rowLayout.value.rowDataCount;
    return dataRowCount > 0 && rowIndex.value < dataRowCount;
  });

  const rowSize = useDerivedValue(() => {
    if (!isRowActive.value) return 0;

    const metrics: RowMetrics = rowLayout.value;
    return getRowMainSize({
      gap,
      isInverted,
      offsets: metrics.offsets,
      rowDataCount: metrics.rowDataCount,
      rowIndex: rowIndex.value,
      totalSize: metrics.totalSize,
    });
  });

  const translateMain = useDerivedValue(() => {
    if (!isRowActive.value) return -9999;

    const metrics: RowMetrics = rowLayout.value;
    const offsets: Float32Array = metrics.offsets;
    const rowIndexValue: number = rowIndex.value;
    const rowStart: number = offsets[rowIndexValue] ?? 0;

    if (!isInverted) return rowStart;

    const rowEnd: number = getRowEndOffset({
      offsets,
      rowDataCount: metrics.rowDataCount,
      rowIndex: rowIndexValue,
      totalSize: metrics.totalSize,
    });
    return metrics.totalSize - rowEnd;
  });

  const rowStyle = useAnimatedStyle(() => {
    const opacity: number = isRowActive.value ? 1 : 0;
    const mainSize: number = rowSize.value;
    const transform: ViewStyle['transform'] = isHorizontal ? [{ translateX: translateMain.value }] : [{ translateY: translateMain.value }];
    return isHorizontal ? { opacity, transform, width: mainSize } : { height: mainSize, opacity, transform };
  });

  const rowBaseStyle: ViewStyle = isHorizontal
    ? { height: crossAxisSize, position: 'absolute' }
    : { position: 'absolute', width: crossAxisSize };

  const rowContent: React.ReactNode[] = columnIndices.map((columnIndex: number) => (
    <RecycledCell
      columnGap={columnGap}
      columnIndex={columnIndex}
      data={data}
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
  isHorizontal,
  itemCrossSize,
  numColumns,
  renderItem,
  rowIndex,
  scrollViewRef,
}: {
  columnGap: number;
  columnIndex: number;
  data: DerivedValue<T[]>;
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

  const item = useDerivedValue(() => {
    const index: number = itemIndex.value;
    return index >= 0 ? data.value[index] : undefined;
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
        isActive,
        item,
        itemIndex,
        rowIndex,
        scrollViewRef,
      })}
    </Animated.View>
  );
}
