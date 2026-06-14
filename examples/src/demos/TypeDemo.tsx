import React, { useEffect, useLayoutEffect, useMemo } from 'react';
import { useStableValue } from '@storesjs/stores';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { EaseView } from 'react-native-ease';
import {
  useAnimatedProps,
  useAnimatedReaction,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  type SharedValue,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  TextView,
  createPreparedText,
  measureText,
  measureTextWidth,
  releasePreparedText,
  type TextMeasureStyle,
} from 'react-native-text-engine';
import { layoutNextLineInRuntime } from 'react-native-text-engine/worklets';
import { runOnUISync } from 'react-native-worklets';
import { DEMO_TRANSITIONS, SPRING_CONFIGS } from '../animation/ease';
import { AnimatedTextView } from '../components/AnimatedTextView';
import { IS_IOS } from '../constants';

const DISPLAY_FAMILY = IS_IOS ? 'TestEpiceneDisplay-Regular' : 'EpiceneDisplay-Regular';
const TEXT_FAMILY = IS_IOS ? 'TestTiemposText-Regular' : 'TiemposText-Regular';
const MONO_FAMILY = IS_IOS ? 'TestFoundersGroteskMono-Regular' : 'FoundersGroteskMono-Regular';

const BG = '#1C0C04';
const DISPLAY_COLOR = '#D08838';
const BODY_COLOR = '#C4A888';
const FOOTER_COLOR = '#5A3C1E';

const BODY_SIZE = 17;
const BODY_LH = 29;
const M = 28;
const OBSTACLE_R = 44;

const INITIAL_ANIMATION_SCALED_DOWN = { opacity: 0, scale: 0.995 };
const RELEASE_SPRING_CONFIG = SPRING_CONFIGS.snappyMediumSpringConfig;

const STATS_GAP = 20;
const STATS_SIZE = 11;
const STATS_LH = 15;

const TITLE = 'Measure';

const BODY_TEXT =
  'The measure is the length of a line of text — the distance the eye ' +
  'travels before returning to the left edge. Too narrow and the rhythm ' +
  'stutters. Too wide and the eye loses its way home.' +
  '\n\n' +
  'Good measure is invisible. The reader moves forward without hesitation, ' +
  'picking up each new line without searching. Somewhere between forty-five ' +
  'and seventy-five characters, most readers find their pace.' +
  '\n\n' +
  'But measure is not fixed. Text flows around what it encounters — an ' +
  'image, a marginal note, the changing contour of a column. Each ' +
  'interruption reshapes the measure, and the text recomposes to fit. ' +
  'Every line finds its own width.' +
  '\n\n' +
  "This is the compositor's ancient problem. A page is not a stack of " +
  'identical lines. It is a surface where text meets obstacles and adapts. ' +
  'The dropped capital pushes the first three lines inward. The marginal ' +
  'figure narrows the column for a span, then releases it. The footnote ' +
  'anchor falls where it falls, and the text accommodates.' +
  '\n\n' +
  'What makes this possible is knowing, before anything is drawn, exactly ' +
  'where each line will break at any given width. The engine measures the ' +
  'text once, then answers layout questions instantly — how many lines at ' +
  'this width, where does line four end, what happens if the measure ' +
  'narrows by thirty points at line seven.' +
  '\n\n' +
  'The result is text that feels liquid. It fills whatever shape it is ' +
  'given, not by stretching or compressing, but by rebreaking — finding ' +
  'new line endings that honor the same rules of word spacing and ' +
  'hyphenation that governed the original setting. The paragraph changes ' +
  'shape, but its texture holds.';

const BODY_PARAGRAPHS = BODY_TEXT.split('\n\n');

const BODY_STYLE: TextMeasureStyle = {
  fontFamily: TEXT_FAMILY,
  fontSize: BODY_SIZE,
  lineHeight: BODY_LH,
};

type BodySlot = {
  text: string;
  visible: boolean;
  width: number;
  x: number;
  y: number;
};

type LayoutState = {
  bodyHeight: number;
  bodyTop: number;
  maxRows: number;
  mw: number;
};

type Obstacle = {
  active: boolean;
  radius: number;
  x: number;
  y: number;
};

type FragmentSpan = {
  width: number;
  x: number;
};

type CompositionResult = {
  lineCount: number;
  slots: BodySlot[];
};

type WorkletContextValue<T> = {
  __workletContextObject: true;
  current: T;
};

const IDLE: Obstacle = { active: false, radius: 0, x: 0, y: 0 };

function resolveLayout(sw: number, sh: number) {
  const mw = sw - M * 2;
  const refSize = 100;
  const refWidth = measureTextWidth(TITLE, {
    fontFamily: DISPLAY_FAMILY,
    fontSize: refSize,
    letterSpacing: -0.5,
  });

  const titleSize = Math.max(48, Math.min(160, Math.round((refSize * mw * 0.88) / Math.max(1, refWidth))));
  const titleLH = Math.round(titleSize * 1.08);
  const titleHeight = Math.ceil(
    measureText(
      TITLE,
      {
        fontFamily: DISPLAY_FAMILY,
        fontSize: titleSize,
        letterSpacing: -0.5,
        lineHeight: titleLH,
      },
      { maxLines: 1, width: mw }
    ).height
  );

  const titleTop = IS_IOS ? 36 : 52;
  const statsTop = titleTop + titleHeight + STATS_GAP;
  const bodyTop = titleTop + titleHeight + 60 + STATS_GAP;
  const bodyHeight = sh - bodyTop - 110;
  const maxRows = Math.max(0, Math.floor(bodyHeight / BODY_LH));

  return {
    bodyHeight,
    bodyTop,
    maxRows,
    mw,
    titleHeight,
    titleLH,
    titleSize,
    titleTop,
    statsTop,
  };
}

function buildEmptySlots(maxRows: number): BodySlot[] {
  'worklet';

  const slots = new Array<BodySlot>(maxRows * 2);
  for (let index = 0; index < slots.length; index += 1) {
    const row = Math.floor(index / 2);
    slots[index] = {
      text: '',
      visible: false,
      width: 0,
      x: 0,
      y: row * BODY_LH,
    };
  }
  return slots;
}

function isInlineWhitespace(char: string | undefined): boolean {
  'worklet';
  return char === '\n' || char === '\r' || char === ' ' || char === '\t';
}

function isWordChar(char: string | undefined): boolean {
  'worklet';

  if (!char) return false;
  const code = char.charCodeAt(0);
  return (
    (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || char === "'" || char === '’' || char === '-'
  );
}

function skipInlineWhitespace(text: string, start: number): number {
  'worklet';

  let index = start;
  while (index < text.length) {
    if (isInlineWhitespace(text[index])) {
      index += 1;
      continue;
    }
    break;
  }
  return index;
}

function resolveSafeFragmentEnd(text: string, start: number, proposedEnd: number): number {
  'worklet';

  if (proposedEnd <= start) return start;
  if (proposedEnd >= text.length) return proposedEnd;

  let end = proposedEnd;
  if (!isWordChar(text[end - 1]) || !isWordChar(text[end])) return end;

  while (end > start) {
    end -= 1;
    if (!isWordChar(text[end - 1]) || !isWordChar(text[end])) return end;
  }
  return end;
}

function resolveRowSpans(mw: number, obs: Obstacle, y: number, minSpanWidth: number): FragmentSpan[] {
  'worklet';

  if (!obs.active || obs.radius <= 1) return [{ width: mw, x: 0 }];

  const dy = y + BODY_LH * 0.5 - obs.y;
  if (Math.abs(dy) >= obs.radius) return [{ width: mw, x: 0 }];

  const halfChord = Math.sqrt(obs.radius * obs.radius - dy * dy);
  const leftWidth = Math.max(0, obs.x - halfChord);
  const rightX = Math.min(mw, obs.x + halfChord);
  const rightWidth = Math.max(0, mw - rightX);
  const spans: FragmentSpan[] = [];

  if (leftWidth >= minSpanWidth) spans.push({ width: leftWidth, x: 0 });
  if (rightWidth >= minSpanWidth) spans.push({ width: rightWidth, x: rightX });
  if (spans.length > 0) return spans;

  if (leftWidth >= rightWidth) return [{ width: Math.max(minSpanWidth, leftWidth), x: 0 }];
  const width = Math.max(minSpanWidth, rightWidth);
  return [{ width, x: mw - width }];
}

function composeBodyInRuntime(
  handles: readonly number[],
  paragraphs: readonly string[],
  mw: number,
  obs: Obstacle,
  bodyHeight: number,
  maxRows: number
): CompositionResult {
  'worklet';
  const slots = buildEmptySlots(maxRows);
  const minSpanWidth = mw * 0.22;

  let lineCount = 0;
  let rowIndex = 0;

  for (let paragraphIndex = 0; paragraphIndex < paragraphs.length; paragraphIndex += 1) {
    const paragraph = paragraphs[paragraphIndex];
    const handle = handles[paragraphIndex];
    let cursor = skipInlineWhitespace(paragraph, 0);

    if (paragraphIndex > 0) rowIndex += 1;
    if (rowIndex >= maxRows || rowIndex * BODY_LH + BODY_LH > bodyHeight) break;

    while (cursor < paragraph.length && rowIndex < maxRows) {
      const rowY = rowIndex * BODY_LH;
      const spans = resolveRowSpans(mw, obs, rowY, minSpanWidth);
      let rowCursor = cursor;
      let slotIndex = 0;
      let didRenderFragment = false;

      for (let spanIndex = 0; spanIndex < spans.length; spanIndex += 1) {
        if (slotIndex >= 2) break;

        const span = spans[spanIndex];
        const line = layoutNextLineInRuntime(handle, rowCursor, span.width);
        if (!line || line.end <= rowCursor) continue;

        const safeEnd = resolveSafeFragmentEnd(paragraph, rowCursor, line.end);
        if (safeEnd <= rowCursor) continue;

        const slot = slots[rowIndex * 2 + slotIndex];
        slot.text = paragraph.slice(rowCursor, safeEnd);
        slot.visible = true;
        slot.width = span.width;
        slot.x = span.x;

        lineCount += 1;
        didRenderFragment = true;
        slotIndex += 1;
        rowCursor = skipInlineWhitespace(paragraph, safeEnd);
        if (rowCursor >= paragraph.length) break;
      }

      if (!didRenderFragment) {
        rowIndex += 1;
        if (rowIndex * BODY_LH + BODY_LH > bodyHeight) break;
        continue;
      }
      if (rowCursor <= cursor) break;

      cursor = rowCursor;
      rowIndex += 1;
      if (rowIndex * BODY_LH + BODY_LH > bodyHeight) break;
    }

    if (rowIndex >= maxRows || rowIndex * BODY_LH + BODY_LH > bodyHeight) break;
  }

  return { lineCount, slots };
}

function nowInRuntime(): number {
  'worklet';
  const maybePerformance = Reflect.get(globalThis, 'performance');
  return maybePerformance ? maybePerformance.now() : 0;
}

function applyComposition(
  bodySlots: SharedValue<BodySlot[]>,
  footerText: SharedValue<string>,
  statsText: SharedValue<string>,
  handles: readonly number[],
  active: number,
  layout: LayoutState,
  pointer: Obstacle,
  radius: number
) {
  'worklet';
  if (active === 0 || handles.length === 0) {
    bodySlots.value = buildEmptySlots(layout.maxRows);
    footerText.value = 'nextLine() · 0 lines';
    statsText.value = '0 µs · 0 lines · 0.0 µs/line';
    return;
  }

  const start = nowInRuntime();
  const result = composeBodyInRuntime(
    handles,
    BODY_PARAGRAPHS,
    layout.mw,
    {
      active: pointer.active || radius > 1,
      radius,
      x: pointer.x,
      y: pointer.y,
    },
    layout.bodyHeight,
    layout.maxRows
  );

  const durationUs = (nowInRuntime() - start) * 1000;
  const usPerLine = result.lineCount > 0 ? durationUs / result.lineCount : 0;

  bodySlots.value = result.slots;
  footerText.value = `nextLine() · ${result.lineCount} lines`;
  statsText.value = `${Math.max(0, Math.round(durationUs))} µs · ${result.lineCount} lines · ${usPerLine.toFixed(1)} µs/line`;
}

function BodySlotView({ bodySlots, bodyTop, index }: { bodySlots: SharedValue<BodySlot[]>; bodyTop: number; index: number }) {
  const animatedProps = useAnimatedProps(() => {
    const slot = bodySlots.value[index];
    return {
      text: slot?.text ?? '',
    };
  });

  const animatedStyle = useAnimatedStyle(() => {
    const slot = bodySlots.value[index];
    return {
      height: BODY_LH,
      left: M + (slot?.x ?? 0),
      opacity: slot?.visible ? 1 : 0,
      position: 'absolute' as const,
      top: bodyTop + (slot?.y ?? 0),
      width: Math.max(1, Math.ceil(slot?.width ?? 0) + 4),
    };
  }, [bodyTop]);

  return (
    <AnimatedTextView
      animatedProps={animatedProps}
      color={BODY_COLOR}
      fontFamily={TEXT_FAMILY}
      fontSize={BODY_SIZE}
      lineHeight={BODY_LH}
      numberOfLines={1}
      style={animatedStyle}
    />
  );
}

function StatsText({ value }: { value: SharedValue<string> }) {
  const animatedProps = useAnimatedProps(() => ({
    text: value.value,
  }));

  return (
    <AnimatedTextView
      animatedProps={animatedProps}
      color={FOOTER_COLOR}
      fontFamily={MONO_FAMILY}
      fontSize={STATS_SIZE}
      numberOfLines={1}
      textAlign="center"
      style={styles.statsFill}
    />
  );
}

export function TypeDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const layout = useMemo(() => resolveLayout(width, height), [height, width]);
  const slotIndices = useMemo(() => Array.from({ length: layout.maxRows * 2 }, (_, index) => index), [layout.maxRows]);

  const bodyHandlesContext = useStableValue<WorkletContextValue<number[]>>(() => ({
    __workletContextObject: true,
    current: [],
  }));

  const bodySlots = useSharedValue<BodySlot[]>(buildEmptySlots(layout.maxRows));
  const footerText = useSharedValue(`nextLine() · 0 lines`);
  const statsText = useSharedValue('0 µs · 0 lines · 0.0 µs/line');
  const activeDemo = useSharedValue(isActive ? 1 : 0);
  const pointer = useSharedValue<Obstacle>(IDLE);
  const pointerRadius = useSharedValue(0);
  const layoutState = useSharedValue<LayoutState>({
    bodyHeight: layout.bodyHeight,
    bodyTop: layout.bodyTop,
    maxRows: layout.maxRows,
    mw: layout.mw,
  });

  useLayoutEffect(() => {
    const nextPrepared = createPreparedText(BODY_PARAGRAPHS, BODY_STYLE);
    const nextHandles = nextPrepared.map(prepared => prepared.handle);
    const nextLayoutState = {
      bodyHeight: layout.bodyHeight,
      bodyTop: layout.bodyTop,
      maxRows: layout.maxRows,
      mw: layout.mw,
    };

    runOnUISync(
      (
        handlesContext,
        slotsValue,
        footerValue,
        statsValue,
        activeValue,
        stateValue,
        pointerValue,
        radiusValue,
        nextBodyHandles,
        nextState
      ) => {
        handlesContext.current = nextBodyHandles;
        stateValue.value = nextState;
        applyComposition(
          slotsValue,
          footerValue,
          statsValue,
          nextBodyHandles,
          activeValue.value,
          nextState,
          pointerValue.value,
          radiusValue.value
        );
      },
      bodyHandlesContext,
      bodySlots,
      footerText,
      statsText,
      activeDemo,
      layoutState,
      pointer,
      pointerRadius,
      nextHandles,
      nextLayoutState
    );

    return () => {
      runOnUISync(
        (handlesContext, slotsValue, footerValue, statsValue, activeValue, maxRows) => {
          activeValue.value = 0;
          handlesContext.current = [];
          slotsValue.value = buildEmptySlots(maxRows);
          footerValue.value = 'nextLine() · 0 lines';
          statsValue.value = '0 µs · 0 lines · 0.0 µs/line';
        },
        bodyHandlesContext,
        bodySlots,
        footerText,
        statsText,
        activeDemo,
        layout.maxRows
      );

      releasePreparedText(nextPrepared);
    };
  }, [
    activeDemo,
    bodyHandlesContext,
    bodySlots,
    footerText,
    statsText,
    layout.bodyHeight,
    layout.bodyTop,
    layout.maxRows,
    layout.mw,
    layoutState,
    pointer,
    pointerRadius,
  ]);

  useEffect(() => {
    activeDemo.value = isActive ? 1 : 0;

    runOnUISync(
      (slotsValue, footerValue, statsValue, activeValue, handlesContext, stateValue, pointerValue, radiusValue) => {
        applyComposition(
          slotsValue,
          footerValue,
          statsValue,
          handlesContext.current,
          activeValue.value,
          stateValue.value,
          pointerValue.value,
          radiusValue.value
        );
      },
      bodySlots,
      footerText,
      statsText,
      activeDemo,
      bodyHandlesContext,
      layoutState,
      pointer,
      pointerRadius
    );
  }, [activeDemo, bodyHandlesContext, bodySlots, footerText, statsText, isActive, layoutState, pointer, pointerRadius]);

  useAnimatedReaction(
    () => {
      const p = pointer.value;
      const radius = pointerRadius.value;
      const layoutValue = layoutState.value;
      return `${activeDemo.value}:${layoutValue.maxRows}:${Math.round(layoutValue.mw)}:${p.active ? 1 : radius > 1 ? 2 : 0}:${Math.round(p.x)}:${Math.round(p.y)}:${Math.round(radius)}`;
    },
    (nextKey, previousKey) => {
      if (nextKey === previousKey || previousKey === null) return;
      applyComposition(
        bodySlots,
        footerText,
        statsText,
        bodyHandlesContext.current,
        activeDemo.value,
        layoutState.value,
        pointer.value,
        pointerRadius.value
      );
    },
    []
  );

  const dragGesture = useMemo(
    () =>
      Gesture.Pan()
        .minDistance(0)
        .onBegin(event => {
          pointer.modify(prev => {
            prev.active = true;
            prev.radius = 0;
            prev.x = event.x - M;
            prev.y = event.y;
            return prev;
          });
          pointerRadius.value = OBSTACLE_R;
        })
        .onChange(event => {
          pointer.modify(prev => {
            prev.active = true;
            prev.radius = 0;
            prev.x = event.x - M;
            prev.y = event.y;
            return prev;
          });
        })
        .onFinalize(() => {
          pointer.modify(prev => {
            prev.active = false;
            return prev;
          });
          pointerRadius.value = withSpring(0, RELEASE_SPRING_CONFIG);
        }),
    [pointer, pointerRadius]
  );

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.page}>
        <EaseView
          animate={{ opacity: isActive ? 1 : 0, scale: isActive ? 1 : 0.995 }}
          initialAnimate={INITIAL_ANIMATION_SCALED_DOWN}
          transition={DEMO_TRANSITIONS.surfaceReveal}
          style={{
            height: layout.titleHeight,
            left: 0,
            position: 'absolute',
            top: layout.titleTop,
            width,
          }}
        >
          <TextView
            color={DISPLAY_COLOR}
            fontFamily={DISPLAY_FAMILY}
            fontSize={layout.titleSize}
            letterSpacing={-0.5}
            numberOfLines={1}
            selectable
            text={TITLE}
            textAlign="center"
          />
        </EaseView>

        <EaseView
          animate={{ opacity: isActive ? 1 : 0, scale: isActive ? 1 : 0.995 }}
          initialAnimate={INITIAL_ANIMATION_SCALED_DOWN}
          pointerEvents="none"
          style={[styles.stats, { top: layout.statsTop }]}
          transition={DEMO_TRANSITIONS.surfaceReveal}
        >
          <StatsText value={statsText} />
        </EaseView>

        <GestureDetector gesture={dragGesture}>
          <EaseView
            animate={{ opacity: isActive ? 1 : 0, scale: isActive ? 1 : 0.995 }}
            initialAnimate={INITIAL_ANIMATION_SCALED_DOWN}
            transition={DEMO_TRANSITIONS.surfaceReveal}
            style={[styles.slotsContainer, { top: layout.bodyTop }]}
          >
            {slotIndices.map(index => (
              <BodySlotView key={index} bodySlots={bodySlots} bodyTop={0} index={index} />
            ))}
          </EaseView>
        </GestureDetector>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  footer: {
    bottom: 100,
    left: M,
    position: 'absolute',
    right: M,
  },
  fill: {
    height: '100%',
    width: '100%',
  },
  footerFill: {
    width: '100%',
  },
  stats: {
    left: M,
    position: 'absolute',
    right: M,
  },
  statsFill: {
    height: STATS_LH,
    textAlign: 'center',
    width: '100%',
  },
  page: {
    flex: 1,
  },
  root: {
    backgroundColor: BG,
    flex: 1,
  },
  slotsContainer: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
});
