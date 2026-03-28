import React, { useCallback, useEffect, useRef } from 'react';
import { Platform, Pressable, SafeAreaView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useStableValue } from '@storesjs/stores';
import { releaseMany, type PreparedTextHandle, type TextLayout, type TextMeasureStyle } from 'react-native-pretext';
import { layoutBatchInRuntime, measureBatchInRuntime, prepareBatchInRuntime } from 'react-native-pretext/worklets';
import Animated, { type DerivedValue, type SharedValue, useAnimatedStyle, useDerivedValue, useSharedValue } from 'react-native-reanimated';
import { runOnUI, scheduleOnRN, scheduleOnRuntime } from 'react-native-worklets';
import { PillSwitch } from '../components/PillSwitch';
import { buildConversation } from '../data/chatData';
import { PreparedHandleText } from '../pretext/PreparedHandleText';
import { getChatPretextRuntime } from '../pretext/runtimes';
import { WorkletText } from '../pretext/WorkletText';
import { uiActions, useUiStore, type WidthMode } from '../state/uiStore';
import { demoTheme } from '../theme/demoTheme';
import { AnimatedList, type RenderItemProps } from '../worklet-list';

type LayoutBuffer = Float32Array;
type HandleBuffer = Float64Array;

type ChatMessage = {
  id: string;
  role: 'assistant' | 'user';
  text: string;
};

const EDGE_INSET = 12;
const ROW_GAP = 10;
const BUBBLE_BORDER_WIDTH = 1;
const BUBBLE_PADDING_X = 15;
const BUBBLE_PADDING_Y = 12;
const TOP_OVERLAY_HEIGHT = 132;
const COMPOSER_HEIGHT = 98;
const PREVIEW_MESSAGE_COUNT = 28;

const MESSAGES: readonly ChatMessage[] = buildConversation(1800);
const MESSAGE_TEXTS = MESSAGES.map(message => message.text);
const MESSAGE_ROLES = MESSAGES.map(message => (message.role === 'user' ? 1 : 0));
const FULL_MESSAGE_INDICES = Array.from({ length: MESSAGES.length }, (_value, index) => index);
const PREVIEW_MESSAGE_INDICES = FULL_MESSAGE_INDICES.slice(0, PREVIEW_MESSAGE_COUNT);

const CHAT_STYLE: TextMeasureStyle = {
  fontSize: 17,
  fontWeight: '500',
  letterSpacing: 0.1,
  lineHeight: 24,
};

const ASSISTANT_CHAT_STYLE = {
  ...CHAT_STYLE,
  color: demoTheme.textPrimary,
};

const USER_CHAT_STYLE = {
  ...CHAT_STYLE,
  color: '#ffffff',
};

const EMPTY_LAYOUT: TextLayout = {
  height: 0,
  lastLineWidth: 0,
  lineCount: 0,
  width: 0,
};

const WIDTH_FACTORS: Record<WidthMode, number> = {
  compact: 0.56,
  phone: 0.72,
  wide: 0.9,
};

const WIDTH_OPTIONS: ReadonlyArray<{ label: string; value: WidthMode }> = [
  { label: 'Compact', value: 'compact' },
  { label: 'Phone', value: 'phone' },
  { label: 'Wide', value: 'wide' },
];

const EMPTY_HANDLES: PreparedTextHandle[] = [];

export function ChatDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const widthMode = useUiStore(state => state.chatWidthMode);
  const jobRef = useRef(0);
  const handlesRef = useRef<PreparedTextHandle[] | null>(null);
  const lastMeasuredTextWidthRef = useRef<number | null>(null);
  const workletRuntime = getChatPretextRuntime();

  const data = useSharedValue<number[]>([]);
  const messageHandles = useSharedValue<HandleBuffer>(new Float64Array(0));
  const bubbleHeights = useSharedValue<LayoutBuffer>(new Float32Array(0));
  const bubbleWidths = useSharedValue<LayoutBuffer>(new Float32Array(0));
  const itemMetricsVersion = useSharedValue(0);
  const layoutMetricText = useSharedValue('...');

  const listWidth = width;
  const listHeight = height;
  const bubbleMaxWidth = Math.max(220, Math.floor((listWidth - EDGE_INSET * 2) * WIDTH_FACTORS[widthMode]));
  const textWidth = Math.max(180, bubbleMaxWidth - BUBBLE_PADDING_X * 2 - BUBBLE_BORDER_WIDTH * 2);

  const applyPreview = useStableValue(() => (jobId: number, handles: HandleBuffer, widths: LayoutBuffer, heights: LayoutBuffer) => {
    if (jobId !== jobRef.current) return;

    runOnUI(
      (
        nextHandles: HandleBuffer,
        nextWidths: LayoutBuffer,
        nextHeights: LayoutBuffer,
        nextIndices: readonly number[],
        metricText: SharedValue<string>,
        handlesValue: SharedValue<HandleBuffer>,
        widthsValue: SharedValue<LayoutBuffer>,
        heightsValue: SharedValue<LayoutBuffer>,
        dataValue: SharedValue<number[]>,
        versionValue: SharedValue<number>
      ) => {
        'worklet';
        handlesValue.value = nextHandles;
        widthsValue.value = nextWidths;
        heightsValue.value = nextHeights;
        dataValue.modify(indices => {
          writeIndices(indices, nextIndices);
          return indices;
        });
        versionValue.value += 1;
        metricText.value = '...';
      }
    )(
      handles,
      widths,
      heights,
      PREVIEW_MESSAGE_INDICES,
      layoutMetricText,
      messageHandles,
      bubbleWidths,
      bubbleHeights,
      data,
      itemMetricsVersion
    );
  });

  const applyRows = useStableValue(
    () =>
      (
        jobId: number,
        nextHandles: PreparedTextHandle[] | null,
        handleIds: HandleBuffer,
        widths: LayoutBuffer,
        heights: LayoutBuffer,
        measuredTextWidth: number,
        nextLayoutMs: number
      ) => {
        if (jobId !== jobRef.current) {
          if (nextHandles && nextHandles.length > 0) releaseMany(nextHandles);
          return;
        }

        if (nextHandles && nextHandles.length > 0) {
          const previousHandles = handlesRef.current;
          if (previousHandles && previousHandles !== nextHandles) {
            releaseMany(previousHandles);
          }
          handlesRef.current = nextHandles;
        }

        const nextMetric = `${nextLayoutMs.toFixed(1)}ms`;
        runOnUI(
          (
            nextHandleIds: HandleBuffer,
            nextWidths: LayoutBuffer,
            nextHeights: LayoutBuffer,
            nextIndices: readonly number[],
            metricText: SharedValue<string>,
            metricValue: string,
            handlesValue: SharedValue<HandleBuffer>,
            widthsValue: SharedValue<LayoutBuffer>,
            heightsValue: SharedValue<LayoutBuffer>,
            dataValue: SharedValue<number[]>,
            versionValue: SharedValue<number>
          ) => {
            'worklet';
            handlesValue.value = nextHandleIds;
            widthsValue.value = nextWidths;
            heightsValue.value = nextHeights;
            dataValue.modify(indices => {
              writeIndices(indices, nextIndices);
              return indices;
            });
            versionValue.value += 1;
            metricText.value = metricValue;
          }
        )(
          handleIds,
          widths,
          heights,
          FULL_MESSAGE_INDICES,
          layoutMetricText,
          nextMetric,
          messageHandles,
          bubbleWidths,
          bubbleHeights,
          data,
          itemMetricsVersion
        );

        lastMeasuredTextWidthRef.current = measuredTextWidth;
      }
  );

  useEffect(() => {
    return () => {
      const handles = handlesRef.current;
      if (!handles || handles.length === 0) return;
      handlesRef.current = null;
      releaseMany(handles);
    };
  }, []);

  useEffect(() => {
    if (!isActive) return;

    const shouldReuseCurrentLayout = handlesRef.current !== null && lastMeasuredTextWidthRef.current === textWidth && data.value.length > 0;
    if (shouldReuseCurrentLayout) return;

    const jobId = jobRef.current + 1;
    jobRef.current = jobId;
    layoutMetricText.value = '...';

    const handles = handlesRef.current;

    if (!handles && data.value.length === 0) {
      scheduleOnRuntime(
        workletRuntime,
        (currentJobId, texts, roles, currentTextWidth, currentBubbleMaxWidth, previewCount, onPreview) => {
          'worklet';

          const previewTexts = texts.slice(0, previewCount);
          const previewRoles = roles.slice(0, previewCount);
          const previewLayouts = measureBatchInRuntime(previewTexts, CHAT_STYLE, {
            width: currentTextWidth,
          });
          const previewHandles = prepareChatHandles(previewTexts, previewRoles);
          const previewHandleIds = buildHandleBufferInRuntime(previewHandles);
          const geometry = buildChatGeometryBuffersInRuntime(previewLayouts, currentBubbleMaxWidth);

          scheduleOnRN(onPreview, currentJobId, previewHandleIds, geometry.widths, geometry.heights);
        },
        jobId,
        MESSAGE_TEXTS,
        MESSAGE_ROLES,
        textWidth,
        bubbleMaxWidth,
        PREVIEW_MESSAGE_COUNT,
        applyPreview
      );
    }

    scheduleOnRuntime(
      workletRuntime,
      (currentJobId, texts, roles, currentHandles, currentTextWidth, currentBubbleMaxWidth, onRows) => {
        'worklet';

        const start = performance.now();
        const handles = currentHandles.length > 0 ? currentHandles : prepareChatHandles(texts, roles);
        const layouts = layoutBatchInRuntime(handles, { width: currentTextWidth });
        const geometry = buildChatGeometryBuffersInRuntime(layouts, currentBubbleMaxWidth);
        const handleIds = buildHandleBufferInRuntime(handles);

        scheduleOnRN(
          onRows,
          currentJobId,
          currentHandles.length > 0 ? null : handles,
          handleIds,
          geometry.widths,
          geometry.heights,
          currentTextWidth,
          performance.now() - start
        );
      },
      jobId,
      MESSAGE_TEXTS,
      MESSAGE_ROLES,
      handles ?? EMPTY_HANDLES,
      textWidth,
      bubbleMaxWidth,
      applyRows
    );
  }, [applyPreview, applyRows, bubbleMaxWidth, data, isActive, layoutMetricText, textWidth, workletRuntime]);

  const keyExtractor = useCallback((messageIndex: number) => {
    'worklet';
    return MESSAGES[messageIndex]?.id ?? `${messageIndex}`;
  }, []);

  const renderItem = useCallback(
    ({ data, itemIndex }: RenderItemProps<number>) => (
      <ChatBubble
        messageHandles={messageHandles}
        bubbleHeights={bubbleHeights}
        bubbleWidths={bubbleWidths}
        data={data}
        itemIndex={itemIndex}
        itemMetricsVersion={itemMetricsVersion}
        listWidth={listWidth}
        messages={MESSAGES}
      />
    ),
    [bubbleHeights, bubbleWidths, itemMetricsVersion, listWidth, messageHandles]
  );

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.backgroundGlowLeft} />
      <View style={styles.backgroundGlowRight} />

      <View style={styles.listShell}>
        <AnimatedList
          contentContainerStyle={styles.listContent}
          data={data}
          estimatedItemSize={92}
          gap={ROW_GAP}
          itemMetricsVersion={itemMetricsVersion}
          itemSizes={bubbleHeights}
          itemWidth={listWidth}
          keyExtractor={keyExtractor}
          listHeight={listHeight}
          listWidth={listWidth}
          renderItem={renderItem}
          rowBuffer={{ above: 10, below: 12 }}
          style={styles.list}
        />
      </View>

      <View pointerEvents="box-none" style={styles.topOverlay}>
        <View style={styles.overlayStrip}>
          <Text style={styles.eyebrow}>Exact row geometry</Text>
          <View style={styles.metricRow}>
            <Metric label="messages" value={MESSAGES.length.toLocaleString()} />
            <Metric label="layout" value={layoutMetricText} />
            <Metric label="max" value={`${bubbleMaxWidth}px`} />
          </View>
        </View>

        <PillSwitch onChange={uiActions.setChatWidthMode} options={WIDTH_OPTIONS} value={widthMode} />
      </View>

      <View style={styles.composerDock}>
        <Pressable style={styles.composerAction}>
          <Text style={styles.composerActionLabel}>+</Text>
        </Pressable>

        <View style={styles.composerInput}>
          <Text style={styles.composerHint}>Prepared input. Exact geometry already known.</Text>
        </View>

        <Pressable style={styles.composerPrimary}>
          <Text style={styles.composerPrimaryLabel}>↗</Text>
        </Pressable>
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
  const assistantHandles = prepareBatchInRuntime(assistantTexts, ASSISTANT_CHAT_STYLE);
  const userHandles = prepareBatchInRuntime(userTexts, USER_CHAT_STYLE);

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
    ids[index] = handles[index]?.id ?? 0;
  }

  return ids;
}

function buildHandleBufferInRuntime(handles: readonly PreparedTextHandle[]): HandleBuffer {
  'worklet';
  return buildHandleBuffer(handles);
}

function writeIndices(target: number[], source: readonly number[]): void {
  'worklet';
  target.length = source.length;

  for (let index = 0; index < source.length; index += 1) {
    target[index] = source[index] ?? -1;
  }
}

function buildChatGeometryBuffersInRuntime(
  layouts: readonly TextLayout[],
  bubbleMaxWidth: number
): {
  heights: LayoutBuffer;
  widths: LayoutBuffer;
} {
  'worklet';
  return buildChatGeometryBuffers(layouts, bubbleMaxWidth);
}

function ChatBubble({
  messageHandles,
  bubbleHeights,
  bubbleWidths,
  data,
  itemIndex,
  itemMetricsVersion,
  listWidth,
  messages,
}: {
  messageHandles: SharedValue<HandleBuffer>;
  bubbleHeights: SharedValue<LayoutBuffer>;
  bubbleWidths: SharedValue<LayoutBuffer>;
  data: RenderItemProps<number>['data'];
  itemIndex: RenderItemProps<number>['itemIndex'];
  itemMetricsVersion: SharedValue<number>;
  listWidth: number;
  messages: readonly ChatMessage[];
}) {
  const messageIndex = useDerivedValue(() => {
    const index = itemIndex.value;
    return data.value[index] ?? -1;
  });

  const role = useDerivedValue<'assistant' | 'user'>(() => {
    const index = messageIndex.value;
    return messages[index]?.role ?? 'assistant';
  });

  const handle = useDerivedValue(() => {
    const index = messageIndex.value;
    return messageHandles.value[index] ?? 0;
  });

  const bubbleStyle = useBubbleStyle(bubbleHeights, bubbleWidths, itemMetricsVersion, messageIndex, role, listWidth);

  return (
    <Animated.View style={[styles.bubble, bubbleStyle]}>
      {Platform.OS === 'ios' ? (
        <PreparedBubbleText handle={handle} />
      ) : (
        <FallbackBubbleText messages={messages} messageIndex={messageIndex} role={role} />
      )}
    </Animated.View>
  );
}

function PreparedBubbleText({ handle }: { handle: DerivedValue<number> }) {
  return <PreparedHandleText ellipsizeMode="clip" handle={handle} style={styles.preparedTextFrame} />;
}

function FallbackBubbleText({
  messages,
  messageIndex,
  role,
}: {
  messages: readonly ChatMessage[];
  messageIndex: DerivedValue<number>;
  role: DerivedValue<'assistant' | 'user'>;
}) {
  const text = useDerivedValue(() => {
    const index = messageIndex.value;
    return messages[index]?.text ?? '';
  });

  const textStyle = useBubbleTextStyle(role);

  return <WorkletText style={[styles.messageText, textStyle]}>{text}</WorkletText>;
}

function useBubbleStyle(
  bubbleHeights: SharedValue<LayoutBuffer>,
  bubbleWidths: SharedValue<LayoutBuffer>,
  itemMetricsVersion: SharedValue<number>,
  messageIndex: DerivedValue<number>,
  role: DerivedValue<'assistant' | 'user'>,
  listWidth: number
) {
  return useAnimatedStyle(() => {
    const metricsVersion = itemMetricsVersion.value;
    if (metricsVersion < 0) return { opacity: 0, width: 0 };

    const index = messageIndex.value;
    if (index < 0) return { opacity: 0, width: 0 };

    const bubbleHeight = bubbleHeights.value[index] ?? 0;
    const bubbleWidth = bubbleWidths.value[index] ?? 0;
    if (!bubbleHeight || !bubbleWidth) return { opacity: 0, width: 0 };

    const isUser = role.value === 'user';
    const left = isUser ? listWidth - EDGE_INSET - bubbleWidth : EDGE_INSET;

    return {
      backgroundColor: isUser ? demoTheme.bubbleUser : demoTheme.bubbleAssistant,
      borderColor: isUser ? 'rgba(227, 230, 255, 0.14)' : demoTheme.borderStrong,
      height: bubbleHeight,
      left,
      opacity: 1,
      width: bubbleWidth,
    };
  }, [listWidth]);
}

function useBubbleTextStyle(role: DerivedValue<'assistant' | 'user'>) {
  return useAnimatedStyle(() => ({
    color: role.value === 'user' ? '#ffffff' : demoTheme.textPrimary,
  }));
}

function Metric({ label, value }: { label: string; value: SharedValue<string> | string }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <WorkletText style={styles.metricValue}>{value}</WorkletText>
    </View>
  );
}

const styles = StyleSheet.create({
  backgroundGlowLeft: {
    backgroundColor: demoTheme.glowBlue,
    borderRadius: 260,
    height: 360,
    left: -140,
    position: 'absolute',
    top: 220,
    width: 360,
  },
  backgroundGlowRight: {
    backgroundColor: demoTheme.glowPurple,
    borderRadius: 280,
    height: 420,
    position: 'absolute',
    right: -170,
    top: 120,
    width: 420,
  },
  bubble: {
    borderRadius: 24,
    borderWidth: BUBBLE_BORDER_WIDTH,
    paddingHorizontal: BUBBLE_PADDING_X,
    paddingVertical: BUBBLE_PADDING_Y,
    position: 'absolute',
    top: 0,
  },
  composerAction: {
    alignItems: 'center',
    backgroundColor: '#0d121a',
    borderColor: demoTheme.borderStrong,
    borderRadius: 20,
    borderWidth: 1,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  composerActionLabel: {
    color: demoTheme.textPrimary,
    fontSize: 22,
    fontWeight: '500',
    marginTop: -2,
  },
  composerDock: {
    alignItems: 'center',
    backgroundColor: 'rgba(7, 9, 14, 0.94)',
    borderTopColor: demoTheme.border,
    borderTopWidth: 1,
    bottom: 0,
    flexDirection: 'row',
    gap: 10,
    left: 0,
    paddingBottom: 16,
    paddingHorizontal: 16,
    paddingTop: 12,
    position: 'absolute',
    right: 0,
  },
  composerHint: {
    color: demoTheme.textSecondary,
    fontSize: 14,
    lineHeight: 20,
  },
  composerInput: {
    backgroundColor: '#0b1017',
    borderColor: demoTheme.border,
    borderRadius: 24,
    borderWidth: 1,
    flex: 1,
    minHeight: 58,
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  composerPrimary: {
    alignItems: 'center',
    backgroundColor: '#44425f',
    borderRadius: 20,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  composerPrimaryLabel: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '800',
    marginTop: -1,
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
    paddingBottom: COMPOSER_HEIGHT + 18,
    paddingTop: TOP_OVERLAY_HEIGHT + 18,
  },
  listShell: {
    flex: 1,
  },
  messageText: {
    fontSize: CHAT_STYLE.fontSize,
    fontWeight: '500',
    letterSpacing: CHAT_STYLE.letterSpacing,
    lineHeight: CHAT_STYLE.lineHeight,
  },
  metric: {
    backgroundColor: 'rgba(12, 16, 23, 0.82)',
    borderColor: demoTheme.border,
    borderRadius: 14,
    borderWidth: 1,
    gap: 2,
    paddingHorizontal: 10,
    paddingVertical: 8,
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
    color: demoTheme.textPrimary,
    fontSize: 15,
    fontWeight: '800',
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
