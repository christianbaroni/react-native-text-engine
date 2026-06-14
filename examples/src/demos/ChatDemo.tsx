import React, { useCallback, useEffect, useRef } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import { EaseView } from 'react-native-ease';
import { releasePreparedText, TextView, type PreparedTextHandle, type TextLayout, type TextMeasureStyle } from 'react-native-text-engine';
import { createPreparedTextsInRuntime, layoutPreparedTextsInRuntime, measureTextsInRuntime } from 'react-native-text-engine/worklets';
import Animated, {
  type DerivedValue,
  type SharedValue,
  useAnimatedProps,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { runOnRuntimeAsync, runOnUISync } from 'react-native-worklets';
import { DEMO_TRANSITIONS } from '../animation/ease';
import { AnimatedPreparedTextView } from '../components/AnimatedPreparedTextView';
import { AnimatedTextView } from '../components/AnimatedTextView';
import { PillSwitch } from '../components/PillSwitch';
import { IS_IOS } from '../constants';
import { buildConversation } from '../data/chatData';
import { useStableValue } from '../hooks/useStableValue';
import { getChatTextEngineRuntime } from '../text-engine/runtimes';
import { uiActions, useUiStore, type WidthMode } from '../state/uiStore';
import { demoTheme } from '../theme/demoTheme';
import { AnimatedList, type ExactLayoutControllerContext, type ExactRowLayout, type RenderItemProps } from '../worklet-list';

type LayoutBuffer = Float32Array;
type HandleBuffer = Float64Array;

type ChatListItem = { handleId: number; messageIndex: number; width: number };
type ChatMessage = { id: string; role: 'assistant' | 'user'; text: string };

const EDGE_INSET = 12;
const ROW_GAP = 10;
const BUBBLE_BORDER_WIDTH = 4 / 3;
const BUBBLE_PADDING_X = 16;
const BUBBLE_PADDING_Y = 16;
const TOP_OVERLAY_HEIGHT = 188;
const PREVIEW_MESSAGE_COUNT = 28;

const MESSAGES: readonly ChatMessage[] = buildConversation(1000);
const MESSAGE_TEXTS = MESSAGES.map(message => message.text);
const MESSAGE_ROLES = MESSAGES.map(message => (message.role === 'user' ? 1 : 0));

const INITIAL_ANIMATION_FROM_ABOVE = { opacity: 0, translateY: -10 };
const INITIAL_ANIMATION_FROM_BELOW = { opacity: 0, translateY: 10 };
const SCROLL_INDICATOR_INSETS = { bottom: 172, top: TOP_OVERLAY_HEIGHT + 20 };

const CHAT_STYLE: TextMeasureStyle = {
  fontSize: 17,
  fontWeight: IS_IOS ? '500' : '400',
  letterSpacing: 0.1,
  lineHeight: 24,
};

const ASSISTANT_CHAT_STYLE = { ...CHAT_STYLE, color: demoTheme.textPrimary };
const USER_CHAT_STYLE = { ...CHAT_STYLE, color: '#ffffff' };
const METRIC_VALUE_TEXT_STYLE = { color: demoTheme.textPrimary, fontSize: 15, fontWeight: '800' as const };

const EMPTY_HANDLES: PreparedTextHandle[] = [];
const EMPTY_LAYOUT: TextLayout = { height: 0, lastLineWidth: 0, lineCount: 0, width: 0 };

const WIDTH_FACTORS: Record<WidthMode, number> = { compact: 0.56, phone: 0.72, wide: 0.9 };
const WIDTH_OPTIONS: ReadonlyArray<{ label: string; value: WidthMode }> = [
  { label: 'Compact', value: 'compact' },
  { label: 'Phone', value: 'phone' },
  { label: 'Wide', value: 'wide' },
];

function publishChatLayout({
  exactLayoutController,
  nextData,
  rowLayoutValue,
}: {
  exactLayoutController: ExactLayoutControllerContext<ChatListItem>;
  nextData: ChatListItem[];
  rowLayoutValue: ExactRowLayout;
}): void {
  runOnUISync(
    (controllerContext, snapshot) => {
      if (controllerContext.current) {
        controllerContext.current.applyLayout(snapshot);
        return;
      }

      controllerContext.pendingSnapshot = snapshot;
    },
    exactLayoutController,
    {
      data: nextData,
      rowLayout: rowLayoutValue,
    }
  );
}

export function ChatDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const widthMode = useUiStore(state => state.chatWidthMode);

  const jobRef = useRef(0);
  const handlesRef = useRef<PreparedTextHandle[] | null>(null);
  const lastMeasuredTextWidthRef = useRef<number | null>(null);

  const workletRuntime = getChatTextEngineRuntime();
  const data = useSharedValue<ChatListItem[]>([]);
  const layoutMetricText = useSharedValue('...');

  const exactLayoutController = useStableValue<ExactLayoutControllerContext<ChatListItem>>(() => ({
    __workletContextObject: true,
    current: undefined,
  }));

  const listWidth = width;
  const listHeight = height;
  const bubbleMaxWidth = Math.max(220, Math.floor((listWidth - EDGE_INSET * 2) * WIDTH_FACTORS[widthMode]));
  const textWidth = Math.max(180, bubbleMaxWidth - BUBBLE_PADDING_X * 2 - BUBBLE_BORDER_WIDTH * 2);

  useEffect(() => {
    return () => {
      const handles = handlesRef.current;
      if (!handles || handles.length === 0) return;
      handlesRef.current = null;
      releasePreparedText(handles);
    };
  }, []);

  useEffect(() => {
    if (!isActive) return;

    const shouldReuseCurrentLayout = handlesRef.current !== null && lastMeasuredTextWidthRef.current === textWidth && data.value.length > 0;
    if (shouldReuseCurrentLayout) return;

    const jobId = jobRef.current + 1;
    jobRef.current = jobId;
    layoutMetricText.set('...');

    const handles = handlesRef.current;

    if (!handles && data.value.length === 0) {
      runOnRuntimeAsync(
        workletRuntime,
        (texts, roles, currentTextWidth, currentBubbleMaxWidth, previewCount) => {
          const previewTexts = texts.slice(0, previewCount);
          const previewRoles = roles.slice(0, previewCount);
          const previewLayouts = measureTextsInRuntime(previewTexts, CHAT_STYLE, { width: currentTextWidth });
          const previewHandles = prepareChatHandles(previewTexts, previewRoles);
          const previewHandleIds = buildHandleBuffer(previewHandles);
          const geometry = buildChatGeometryBuffers(previewLayouts, currentBubbleMaxWidth);

          return {
            handles: previewHandles,
            items: buildChatItems(previewHandleIds, geometry.widths),
            rowLayout: buildChatRowLayout(geometry.heights),
          };
        },
        MESSAGE_TEXTS,
        MESSAGE_ROLES,
        textWidth,
        bubbleMaxWidth,
        PREVIEW_MESSAGE_COUNT
      ).then(preview => {
        if (jobId !== jobRef.current) {
          if (preview.handles.length > 0) releasePreparedText(preview.handles);
          return;
        }

        const previousHandles = handlesRef.current;
        handlesRef.current = preview.handles;
        publishChatLayout({
          exactLayoutController,
          nextData: preview.items,
          rowLayoutValue: preview.rowLayout,
        });
        if (previousHandles && previousHandles !== preview.handles) releasePreparedText(previousHandles);
        layoutMetricText.set('...');
      });
    }

    runOnRuntimeAsync(
      workletRuntime,
      (texts, roles, currentHandles, currentTextWidth, currentBubbleMaxWidth) => {
        const start = Date.now();
        const handles = currentHandles.length > 0 ? currentHandles : prepareChatHandles(texts, roles);
        const layouts = layoutPreparedTextsInRuntime(handles, { width: currentTextWidth });
        const geometry = buildChatGeometryBuffers(layouts, currentBubbleMaxWidth);
        const handleIds = buildHandleBuffer(handles);

        return {
          handles: currentHandles.length > 0 ? null : handles,
          items: buildChatItems(handleIds, geometry.widths),
          measuredTextWidth: currentTextWidth,
          nextLayoutMs: Date.now() - start,
          rowLayout: buildChatRowLayout(geometry.heights),
        };
      },
      MESSAGE_TEXTS,
      MESSAGE_ROLES,
      handles ?? EMPTY_HANDLES,
      textWidth,
      bubbleMaxWidth
    ).then(rows => {
      if (jobId !== jobRef.current) {
        if (rows.handles && rows.handles.length > 0) releasePreparedText(rows.handles);
        return;
      }

      const previousHandles = rows.handles && rows.handles.length > 0 ? handlesRef.current : null;
      if (rows.handles && rows.handles.length > 0) handlesRef.current = rows.handles;

      publishChatLayout({ exactLayoutController, nextData: rows.items, rowLayoutValue: rows.rowLayout });
      if (previousHandles && previousHandles !== rows.handles) releasePreparedText(previousHandles);

      layoutMetricText.set(`${rows.nextLayoutMs.toFixed(1)}ms`);
      lastMeasuredTextWidthRef.current = rows.measuredTextWidth;
    });
  }, [bubbleMaxWidth, data, exactLayoutController, isActive, layoutMetricText, textWidth, workletRuntime]);

  const keyExtractor = useCallback((chatItem: ChatListItem) => {
    'worklet';
    const index = chatItem.messageIndex;
    return MESSAGES[index]?.id ?? `${index}`;
  }, []);

  const renderItem = useCallback(
    ({ item }: RenderItemProps<ChatListItem>) => <ChatBubble item={item} listWidth={listWidth} messages={MESSAGES} />,
    [listWidth]
  );

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.listShell}>
        <AnimatedList
          contentContainerStyle={styles.listContent}
          data={data}
          exactLayoutController={exactLayoutController}
          gap={ROW_GAP}
          itemSize={92}
          itemWidth={listWidth}
          initialScrollToEnd
          keyExtractor={keyExtractor}
          listHeight={listHeight}
          listWidth={listWidth}
          maintainScrollAtEdge={{ mode: 'always', edge: 'end' }}
          renderItem={renderItem}
          rowBuffer={10}
          scrollIndicatorInsets={SCROLL_INDICATOR_INSETS}
          style={styles.list}
        />
      </View>

      <View pointerEvents="box-none" style={styles.topOverlay}>
        <EaseView
          animate={{ opacity: isActive ? 1 : 0, translateY: isActive ? 0 : -10 }}
          initialAnimate={INITIAL_ANIMATION_FROM_ABOVE}
          transition={DEMO_TRANSITIONS.overlayReveal}
        >
          <View style={styles.overlayStrip}>
            <TextView style={styles.eyebrow}>Exact row geometry</TextView>
            <View style={styles.metricRow}>
              <Metric label="messages" value={MESSAGES.length.toLocaleString()} />
              <Metric label="layout" value={layoutMetricText} />
              <Metric label="max" value={`${bubbleMaxWidth}px`} />
            </View>
          </View>
        </EaseView>

        <EaseView
          animate={{ opacity: isActive ? 1 : 0, translateY: isActive ? 0 : 10 }}
          initialAnimate={INITIAL_ANIMATION_FROM_BELOW}
          transition={DEMO_TRANSITIONS.overlayReveal}
        >
          <PillSwitch onChange={uiActions.setChatWidthMode} options={WIDTH_OPTIONS} value={widthMode} />
        </EaseView>
      </View>
    </SafeAreaView>
  );
}

function buildChatGeometryBuffers(
  layouts: readonly TextLayout[],
  bubbleMaxWidth: number
): {
  heights: LayoutBuffer;
  widths: LayoutBuffer;
} {
  'worklet';
  const heights = new Float32Array(layouts.length);
  const widths = new Float32Array(layouts.length);

  for (let index = 0; index < layouts.length; index += 1) {
    const layout = layouts[index] ?? EMPTY_LAYOUT;
    heights[index] = Math.ceil(layout.height + BUBBLE_PADDING_Y * 2 + BUBBLE_BORDER_WIDTH * 2);
    widths[index] = Math.min(bubbleMaxWidth, Math.ceil(layout.width + BUBBLE_PADDING_X * 2 + BUBBLE_BORDER_WIDTH * 2));
  }

  return { heights, widths };
}

function buildChatRowLayout(heights: LayoutBuffer): ExactRowLayout {
  'worklet';
  const rowDataCount = heights.length;
  const offsets = new Float32Array(rowDataCount);
  const sizes = new Float32Array(rowDataCount);
  let totalSize = 0;

  for (let rowIndex = 0; rowIndex < rowDataCount; rowIndex += 1) {
    offsets[rowIndex] = totalSize;
    const gapSize = rowIndex < rowDataCount - 1 ? ROW_GAP : 0;
    const size = (heights[rowIndex] ?? 0) + gapSize;
    sizes[rowIndex] = size;
    totalSize += size;
  }

  return { offsets, rowDataCount, sizes, totalSize };
}

function prepareChatHandles(texts: readonly string[], roles: readonly number[]): PreparedTextHandle[] {
  'worklet';

  const assistantTexts: string[] = [];
  const assistantIndices: number[] = [];
  const userTexts: string[] = [];
  const userIndices: number[] = [];

  for (let index = 0; index < texts.length; index += 1) {
    const text = texts[index] ?? '';
    if (roles[index] === 1) {
      userIndices.push(index);
      userTexts.push(text);
    } else {
      assistantIndices.push(index);
      assistantTexts.push(text);
    }
  }

  const handles = new Array<PreparedTextHandle>(texts.length);
  const assistantHandles = createPreparedTextsInRuntime(assistantTexts, ASSISTANT_CHAT_STYLE);
  const userHandles = createPreparedTextsInRuntime(userTexts, USER_CHAT_STYLE);

  for (let index = 0; index < assistantIndices.length; index += 1) {
    handles[assistantIndices[index] ?? 0] = assistantHandles[index];
  }

  for (let index = 0; index < userIndices.length; index += 1) {
    handles[userIndices[index] ?? 0] = userHandles[index];
  }

  return handles;
}

function buildHandleBuffer(handles: readonly PreparedTextHandle[]): HandleBuffer {
  'worklet';
  const ids = new Float64Array(handles.length);

  for (let index = 0; index < handles.length; index += 1) {
    ids[index] = handles[index]?.handle ?? 0;
  }

  return ids;
}

function buildChatItems(handleIds: HandleBuffer, widths: LayoutBuffer): ChatListItem[] {
  'worklet';
  const count = Math.min(handleIds.length, widths.length);
  const items = new Array<ChatListItem>(count);

  for (let index = 0; index < count; index += 1) {
    items[index] = {
      handleId: handleIds[index] ?? 0,
      messageIndex: index,
      width: widths[index] ?? 0,
    };
  }

  return items;
}

function ChatBubble({
  item,
  listWidth,
  messages,
}: {
  item: RenderItemProps<ChatListItem>['item'];
  listWidth: number;
  messages: readonly ChatMessage[];
}) {
  const messageIndex = useDerivedValue(() => {
    return item.value?.messageIndex ?? -1;
  });

  const role = useDerivedValue<'assistant' | 'user'>(() => {
    const index = messageIndex.value;
    return messages[index]?.role ?? 'assistant';
  });

  const handle = useDerivedValue(() => {
    return item.value?.handleId ?? 0;
  });

  const bubbleStyle = useBubbleStyle(item, messageIndex, role, listWidth);

  return (
    <Animated.View style={[styles.bubble, bubbleStyle]}>
      <PreparedBubbleText handle={handle} />
    </Animated.View>
  );
}

function PreparedBubbleText({ handle }: { handle: DerivedValue<number> }) {
  const animatedProps = useAnimatedProps(() => ({
    handle: handle.value,
  }));

  return <AnimatedPreparedTextView animatedProps={animatedProps} ellipsizeMode="clip" style={styles.preparedTextFrame} />;
}

function useBubbleStyle(
  item: RenderItemProps<ChatListItem>['item'],
  messageIndex: DerivedValue<number>,
  role: DerivedValue<'assistant' | 'user'>,
  listWidth: number
) {
  return useAnimatedStyle(() => {
    const index = messageIndex.value;
    if (index < 0) return { opacity: 0, width: 0 };

    const bubbleWidth = item.value?.width ?? 0;
    if (!bubbleWidth) return { opacity: 0, width: 0 };

    const isUser = role.value === 'user';
    const left = isUser ? listWidth - EDGE_INSET - bubbleWidth : EDGE_INSET;

    return {
      backgroundColor: isUser ? demoTheme.bubbleUser : demoTheme.bubbleAssistant,
      borderColor: isUser ? 'rgba(255, 255, 255, 0.2)' : demoTheme.borderStrong,
      left,
      opacity: 1,
      width: bubbleWidth,
    };
  }, [listWidth]);
}

function Metric({ label, value }: { label: string; value: SharedValue<string> | string }) {
  return (
    <View style={styles.metric}>
      <TextView style={styles.metricLabel}>{label}</TextView>
      {typeof value === 'string' ? <TextView style={styles.metricValue}>{value}</TextView> : <MetricValueText value={value} />}
    </View>
  );
}

function MetricValueText({ value }: { value: SharedValue<string> }) {
  const animatedProps = useAnimatedProps(() => ({
    text: value.value,
  }));

  return (
    <AnimatedTextView
      animatedProps={animatedProps}
      color={METRIC_VALUE_TEXT_STYLE.color}
      fontSize={METRIC_VALUE_TEXT_STYLE.fontSize}
      fontWeight={METRIC_VALUE_TEXT_STYLE.fontWeight}
      style={styles.metricValueFill}
    />
  );
}

const styles = StyleSheet.create({
  bubble: {
    borderRadius: 24,
    borderCurve: 'continuous',
    borderWidth: BUBBLE_BORDER_WIDTH,
    height: '100%',
    overflow: 'hidden',
    paddingHorizontal: BUBBLE_PADDING_X,
    paddingVertical: BUBBLE_PADDING_Y,
    position: 'absolute',
    top: 0,
  },
  eyebrow: {
    color: demoTheme.accentBlue,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.9,
    textTransform: 'uppercase',
  },
  list: {
    flex: 1,
  },
  listContent: {
    paddingBottom: TOP_OVERLAY_HEIGHT + 20,
    paddingTop: TOP_OVERLAY_HEIGHT + 20,
  },
  listShell: {
    flex: 1,
  },
  metric: {
    backgroundColor: 'rgba(12, 16, 23, 0.82)',
    borderColor: demoTheme.border,
    borderCurve: 'continuous',
    borderRadius: 14,
    borderWidth: BUBBLE_BORDER_WIDTH,
    gap: 6,
    overflow: 'hidden',
    paddingHorizontal: 10,
    paddingVertical: 12,
  },
  metricLabel: {
    color: demoTheme.textTertiary,
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
  },
  metricRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  metricValue: {
    ...METRIC_VALUE_TEXT_STYLE,
  },
  metricValueFill: {
    flex: 1,
  },
  overlayStrip: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  preparedTextFrame: {
    flex: 1,
  },
  root: {
    backgroundColor: demoTheme.root,
    flex: 1,
  },
  topOverlay: {
    gap: 12,
    left: 0,
    paddingHorizontal: 16,
    paddingTop: 112,
    position: 'absolute',
    right: 0,
    zIndex: 2,
  },
});
