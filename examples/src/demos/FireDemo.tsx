import React, { useEffect, useLayoutEffect, useMemo } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GlyphFieldView, createGlyphField } from 'react-native-text-engine';
import { commitGlyphFieldBuffersInRuntime, createGlyphFieldBuffersInRuntime } from 'react-native-text-engine/worklets';
import { createSynchronizable, runOnRuntimeSync, scheduleOnRuntime, type Synchronizable } from 'react-native-worklets';
import { useStableValue } from '../hooks/useStableValue';
import { getFieldTextEngineRuntime } from '../text-engine/runtimes';
import {
  DEFAULT_FIRE_CONTROLS,
  FIRE_GLYPH_PALETTE,
  FIRE_STYLE,
  FIRE_VARIANTS,
  createFireFrameBuffer,
  createFireRuntimeInput,
  resolveFireConfig,
  stepFireRuntime,
} from './fireEngine';

type FireControlState = {
  bodyBias: number;
  enabled: boolean;
  gestureStartBodyBias: number;
  gestureStartWind: number;
  running: boolean;
  wind: number;
};

const MAX_BODY_BIAS = 0.4;
const MAX_WIND = 2.2;
const BODY_DRAG_GAIN = 10;
const WIND_DRAG_GAIN = 10;

function clampValue(value: number, min: number, max: number): number {
  'worklet';
  return Math.max(min, Math.min(max, value));
}

function buildInitialControlState(): FireControlState {
  return {
    bodyBias: DEFAULT_FIRE_CONTROLS.bodyBias,
    enabled: false,
    gestureStartBodyBias: DEFAULT_FIRE_CONTROLS.bodyBias,
    gestureStartWind: DEFAULT_FIRE_CONTROLS.wind,
    running: true,
    wind: DEFAULT_FIRE_CONTROLS.wind,
  };
}

export function FireDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const config = useMemo(() => resolveFireConfig(width, height), [height, width]);
  const runtimeInput = useMemo(() => createFireRuntimeInput(config), [config]);
  const fieldRuntime = useStableValue(() => getFieldTextEngineRuntime());

  const field = useMemo(
    () =>
      createGlyphField({
        columns: config.cols,
        fontFamily: FIRE_STYLE.fontFamily,
        fontSize: FIRE_STYLE.fontSize ?? 16,
        glyphPalette: FIRE_GLYPH_PALETTE,
        letterSpacing: FIRE_STYLE.letterSpacing,
        lineHeight: FIRE_STYLE.lineHeight ?? 20,
        rows: config.rows,
        textAlign: 'center',
        variants: FIRE_VARIANTS,
      }),
    [config.cols, config.rows]
  );

  const control = useStableValue<Synchronizable<FireControlState>>(() =>
    createSynchronizable<FireControlState>(buildInitialControlState())
  );

  const fieldHandle = field.handle;

  useLayoutEffect(() => {
    control.setBlocking(buildInitialControlState());

    scheduleOnRuntime(
      fieldRuntime,
      (fireControl, handle, cellCount, fieldCellCount, input) => {
        const buffers = createGlyphFieldBuffersInRuntime(handle);
        const frameBuffer = createFireFrameBuffer(cellCount, fieldCellCount);
        frameBuffer.current.glyphIndices = buffers.glyphIndices;
        frameBuffer.current.variantIndices = buffers.variantIndices;

        let lastTimestamp = 0;

        const tick = (timestamp: number) => {
          const state = fireControl.getDirty();
          if (!state.running) return;

          requestAnimationFrame(tick);

          if (!state.enabled) {
            lastTimestamp = 0;
            return;
          }

          const deltaMs = lastTimestamp === 0 ? 16.67 : Math.min(33.34, timestamp - lastTimestamp);
          lastTimestamp = timestamp;
          frameBuffer.current.phase += deltaMs / 1000;
          stepFireRuntime(input, frameBuffer, frameBuffer.current.phase, {
            bodyBias: state.bodyBias,
            wind: state.wind,
          });
          commitGlyphFieldBuffersInRuntime(handle);
        };

        requestAnimationFrame(tick);
      },
      control,
      fieldHandle,
      runtimeInput.cellCount,
      runtimeInput.fieldCols * runtimeInput.fieldRows,
      runtimeInput
    );

    const initialFrame = stepFireRuntime(
      runtimeInput,
      createFireFrameBuffer(runtimeInput.cellCount, runtimeInput.fieldCols * runtimeInput.fieldRows),
      0,
      DEFAULT_FIRE_CONTROLS
    );

    field.update(initialFrame.glyphIndices, initialFrame.variantIndices);
    return () => {
      control.setBlocking(state => ({
        ...state,
        enabled: false,
        running: false,
      }));

      runOnRuntimeSync(fieldRuntime, () => {
        return 0;
      });

      field.release();
    };
  }, [control, field, fieldHandle, fieldRuntime, runtimeInput]);

  useEffect(() => {
    control.setBlocking(state => ({
      ...state,
      enabled: isActive,
    }));
  }, [control, isActive]);

  const dragGesture = useMemo(
    () =>
      Gesture.Pan()
        .minDistance(0)
        .onBegin(() => {
          control.setBlocking(state => ({
            ...state,
            gestureStartBodyBias: state.bodyBias,
            gestureStartWind: state.wind,
          }));
        })
        .onChange(event => {
          control.setBlocking(state => ({
            ...state,
            bodyBias: clampValue(
              state.gestureStartBodyBias - (event.translationY / config.artHeight) * BODY_DRAG_GAIN,
              -MAX_BODY_BIAS,
              MAX_BODY_BIAS
            ),
            wind: clampValue(state.gestureStartWind + (event.translationX / config.artWidth) * WIND_DRAG_GAIN, -MAX_WIND, MAX_WIND),
          }));
        }),
    [config.artHeight, config.artWidth, control]
  );

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.stage}>
        <GestureDetector gesture={dragGesture}>
          <View style={[styles.canvas, { height: config.artHeight, width: config.artWidth }]}>
            <GlyphFieldView handle={fieldHandle} style={styles.fieldSurface} />
          </View>
        </GestureDetector>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  canvas: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    bottom: 100,
  },
  fieldSurface: {
    height: '100%',
    width: '100%',
  },
  root: {
    backgroundColor: '#020100',
    flex: 1,
    overflow: 'hidden',
  },
  stage: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    paddingBottom: 160,
    paddingHorizontal: 12,
    paddingTop: 16,
  },
});
