import React, { useLayoutEffect, useMemo } from 'react';
import { SafeAreaView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useStableValue } from '@storesjs/stores';
import Animated, { makeMutable, useFrameCallback, useAnimatedStyle, useSharedValue, type SharedValue } from 'react-native-reanimated';
import { WorkletText } from '../pretext/WorkletText';
import { createTextFieldRuntimeInput, FIELD_STYLE, resolveTextFieldConfig, stepTextFieldRuntime } from './textFieldEngine';
import { demoTheme } from '../theme/demoTheme';

type AnimatedEmitter = {
  opacity: SharedValue<number>;
  r: SharedValue<number>;
  x: SharedValue<number>;
  y: SharedValue<number>;
};

const EMITTER_COLORS = ['#7987b6', '#c79a63', '#b77a92', '#9cc1b2'] as const;

export function TextFieldDemo({ isActive = true }: { isActive?: boolean }) {
  const { width } = useWindowDimensions();
  const config = useMemo(() => resolveTextFieldConfig(width), [width]);
  const runtimeInput = useMemo(() => createTextFieldRuntimeInput(config), [config]);
  const initialFrame = useMemo(() => stepTextFieldRuntime(runtimeInput, 0), [runtimeInput]);

  const active = useSharedValue(isActive ? 1 : 0);
  const fieldText = useSharedValue(initialFrame.text);
  const phase = useSharedValue(0);
  const runtimeInputValue = useSharedValue(runtimeInput);

  const emitters = useStableValue<AnimatedEmitter[]>(() =>
    initialFrame.emitters.map(emitter => ({
      opacity: makeMutable(emitter.opacity),
      r: makeMutable(emitter.r),
      x: makeMutable(emitter.x - emitter.r),
      y: makeMutable(emitter.y - emitter.r),
    }))
  );

  useLayoutEffect(() => {
    active.value = isActive ? 1 : 0;
  }, [active, isActive]);

  useLayoutEffect(() => {
    runtimeInputValue.value = runtimeInput;
    phase.value = 0;
    const next = stepTextFieldRuntime(runtimeInput, 0);
    fieldText.value = next.text;

    for (let index = 0; index < emitters.length; index += 1) {
      const emitter = emitters[index];
      const nextEmitter = next.emitters[index];
      if (!emitter || !nextEmitter) continue;

      emitter.opacity.value = nextEmitter.opacity;
      emitter.r.value = nextEmitter.r;
      emitter.x.value = nextEmitter.x - nextEmitter.r;
      emitter.y.value = nextEmitter.y - nextEmitter.r;
    }
  }, [emitters, fieldText, phase, runtimeInput, runtimeInputValue]);

  const onFrame = useStableValue(() => (frameInfo: { timeSincePreviousFrame: number | null }) => {
    'worklet';

    if (active.value === 0) return;

    const deltaMs = frameInfo.timeSincePreviousFrame ?? 16.67;
    phase.value += deltaMs / 1000;

    const next = stepTextFieldRuntime(runtimeInputValue.value, phase.value);
    fieldText.value = next.text;

    for (let index = 0; index < emitters.length; index += 1) {
      const emitter = emitters[index];
      const nextEmitter = next.emitters[index];
      if (!emitter || !nextEmitter) continue;

      emitter.opacity.value = nextEmitter.opacity;
      emitter.r.value = nextEmitter.r;
      emitter.x.value = nextEmitter.x - nextEmitter.r;
      emitter.y.value = nextEmitter.y - nextEmitter.r;
    }
  });

  useFrameCallback(onFrame);

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.screen}>
        <View style={styles.header}>
          <Text style={styles.eyebrow}>Variable type field</Text>
          <View style={styles.metricRow}>
            <Metric label="rows" value={`${config.rows}`} />
            <Metric label="cols" value={`${config.cols}`} />
            <Metric label="glyphs" value={`${config.rows * config.cols}`} />
          </View>
        </View>

        <View style={styles.fieldShell}>
          <View pointerEvents="none" style={[styles.field, { height: config.artHeight + 44, width: config.artWidth + 44 }]}>
            <View style={styles.fieldGlow} />
            {emitters.map((emitter, index) => (
              <EmitterNode color={EMITTER_COLORS[index] ?? '#ffffff'} emitter={emitter} key={index} />
            ))}
            <View style={[styles.textFrame, { height: config.artHeight, width: config.artWidth + 8 }]}>
              <WorkletText
                ellipsizeMode="clip"
                numberOfLines={config.rows}
                style={[
                  styles.fieldText,
                  {
                    height: config.artHeight,
                    width: config.artWidth + 8,
                  },
                ]}
              >
                {fieldText}
              </WorkletText>
            </View>
          </View>
        </View>
        <Text style={styles.caption}>One Shared Value text owner. Precomputed measured glyph lookup.</Text>
      </View>
    </SafeAreaView>
  );
}

function EmitterNode({ color, emitter }: { color: string; emitter: AnimatedEmitter }) {
  const style = useAnimatedStyle(() => {
    const size = emitter.r.value * 2;

    return {
      backgroundColor: color,
      borderRadius: emitter.r.value,
      height: size,
      left: emitter.x.value,
      opacity: emitter.opacity.value * 0.18,
      top: emitter.y.value,
      width: size,
    };
  });

  return <Animated.View style={[styles.emitter, style]} />;
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  caption: {
    color: demoTheme.textTertiary,
    fontSize: 12,
    letterSpacing: 0.3,
    lineHeight: 18,
    paddingHorizontal: 20,
    paddingTop: 14,
    textAlign: 'center',
  },
  eyebrow: {
    color: demoTheme.accentBlue,
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 1.1,
    textTransform: 'uppercase',
  },
  emitter: {
    position: 'absolute',
  },
  field: {
    backgroundColor: '#04060b',
    borderColor: demoTheme.borderStrong,
    borderRadius: 30,
    borderWidth: 1,
    overflow: 'hidden',
    position: 'relative',
  },
  fieldGlow: {
    backgroundColor: demoTheme.glowBlue,
    borderRadius: 220,
    height: 260,
    left: -90,
    position: 'absolute',
    top: -70,
    width: 260,
  },
  fieldShell: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  fieldText: {
    color: '#b79a63',
    fontFamily: FIELD_STYLE.fontFamily,
    fontSize: FIELD_STYLE.fontSize,
    fontWeight: '500',
    letterSpacing: FIELD_STYLE.letterSpacing,
    lineHeight: FIELD_STYLE.lineHeight,
    textAlign: 'center',
  },
  header: {
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 16,
    paddingTop: 112,
  },
  metric: {
    backgroundColor: demoTheme.panelMuted,
    borderColor: demoTheme.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  metricLabel: {
    color: demoTheme.textTertiary,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
  },
  metricRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  metricValue: {
    color: demoTheme.textPrimary,
    fontSize: 17,
    fontWeight: '800',
  },
  root: {
    backgroundColor: demoTheme.root,
    flex: 1,
  },
  screen: {
    flex: 1,
  },
  textFrame: {
    left: 18,
    overflow: 'hidden',
    position: 'absolute',
    top: 22,
  },
});
