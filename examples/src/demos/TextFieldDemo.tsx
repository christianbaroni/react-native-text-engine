import React, { useEffect, useLayoutEffect, useMemo } from 'react';
import { StyleSheet, View, useWindowDimensions, type LayoutChangeEvent } from 'react-native';
import { useStableValue } from '@storesjs/stores';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useFrameCallback, useSharedValue } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GlyphFieldView, TextView, createGlyphField } from 'react-native-text-engine';
import { commitGlyphFieldBuffersInRuntime, createGlyphFieldBuffersInRuntime } from 'react-native-text-engine/worklets';
import { runOnUISync } from 'react-native-worklets';
import {
  FIELD_STYLE,
  FIELD_VARIANTS,
  FIELD_GLYPH_PALETTE,
  createTextFieldFrameBuffer,
  createTextFieldRuntimeInput,
  resolveTextFieldConfig,
  stepTextFieldRuntime,
  type TextFieldFrameBuffer,
  type TextFieldPointer,
} from './textFieldEngine';
import { demoTheme } from '../theme/demoTheme';

type WorkletContextValue<T> = {
  __workletContextObject: true;
  current: T;
};

export function TextFieldDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const config = useMemo(() => resolveTextFieldConfig(width, height), [height, width]);
  const runtimeInput = useMemo(() => createTextFieldRuntimeInput(config), [config]);
  const frameBuffer = useStableValue<TextFieldFrameBuffer>(() => createTextFieldFrameBuffer(config.rows * config.cols));

  const field = useMemo(
    () =>
      createGlyphField({
        columns: config.cols,
        fontFamily: FIELD_STYLE.fontFamily,
        fontSize: FIELD_STYLE.fontSize ?? 18,
        glyphPalette: FIELD_GLYPH_PALETTE,
        letterSpacing: FIELD_STYLE.letterSpacing,
        lineHeight: FIELD_STYLE.lineHeight ?? 20,
        rows: config.rows,
        textAlign: 'center',
        variants: FIELD_VARIANTS,
      }),
    [config.cols, config.rows]
  );

  const active = useSharedValue(isActive ? 1 : 0);
  const bufferContext = useStableValue<WorkletContextValue<TextFieldFrameBuffer | undefined>>(() => ({
    __workletContextObject: true,
    current: undefined,
  }));

  const fieldFrame = useSharedValue({
    height: config.artHeight,
    width: config.artWidth,
    x: 0,
    y: 0,
  });

  const phase = useSharedValue(0);
  const pointer = useSharedValue<TextFieldPointer>({
    active: false,
    x: 0,
    y: 0,
  });

  const fieldHandle = field.handle;

  useEffect(
    () => () => {
      runOnUISync(
        (currentBufferContext, currentActive) => {
          currentActive.value = 0;
          currentBufferContext.current = undefined;
        },
        bufferContext,
        active
      );

      field.release();
    },
    [active, bufferContext, field]
  );

  useLayoutEffect(() => {
    active.value = isActive ? 1 : 0;
  }, [active, isActive]);

  useLayoutEffect(() => {
    phase.value = 0;
    fieldFrame.value = {
      height: config.artHeight,
      width: config.artWidth,
      x: 0,
      y: 0,
    };

    runOnUISync(
      (currentBufferContext, handle, cellCount) => {
        const buffers = createGlyphFieldBuffersInRuntime(handle);
        const nextFrameBuffer = createTextFieldFrameBuffer(cellCount);
        nextFrameBuffer.current = {
          emitters: nextFrameBuffer.current.emitters,
          glyphIndices: buffers.glyphIndices,
          variantIndices: buffers.variantIndices,
        };
        currentBufferContext.current = nextFrameBuffer;
      },
      bufferContext,
      fieldHandle,
      runtimeInput.cellCount
    );

    const frame = stepTextFieldRuntime(runtimeInput, frameBuffer, 0, { active: false, x: 0, y: 0 });
    field.update(frame.glyphIndices, frame.variantIndices);
  }, [bufferContext, config.artHeight, config.artWidth, field, fieldFrame, fieldHandle, frameBuffer, phase, runtimeInput]);

  const updateFieldFrame = (event: LayoutChangeEvent) => {
    const info = event.nativeEvent.layout;
    fieldFrame.value = { height: info.height, width: info.width, x: info.x, y: info.y };
  };

  useFrameCallback(frameInfo => {
    if (active.value === 0) return;
    const currentFrameBuffer = bufferContext.current;
    if (!currentFrameBuffer) return;

    phase.value += (frameInfo.timeSincePreviousFrame ?? 16.67) / 1000;
    stepTextFieldRuntime(runtimeInput, currentFrameBuffer, phase.value, pointer.value);
    commitGlyphFieldBuffersInRuntime(fieldHandle);
  });

  const dragGesture = useMemo(
    () =>
      Gesture.Pan()
        .minDistance(0)
        .onBegin(event => {
          pointer.modify(prev => {
            const frame = fieldFrame.value;
            prev.active = true;
            prev.x = event.x - frame.x;
            prev.y = event.y - frame.y;
            return prev;
          });
        })
        .onChange(event => {
          pointer.modify(prev => {
            const frame = fieldFrame.value;
            prev.active = true;
            prev.x = event.x - frame.x;
            prev.y = event.y - frame.y;
            return prev;
          });
        })
        .onFinalize(() => {
          pointer.modify(prev => {
            prev.active = false;
            return prev;
          });
        }),
    [fieldFrame, pointer]
  );

  return (
    <SafeAreaView style={styles.root}>
      <GestureDetector gesture={dragGesture}>
        <View style={styles.stage}>
          <View onLayout={updateFieldFrame} style={[styles.textField, { height: config.artHeight, width: config.artWidth }]}>
            <GlyphFieldView handle={fieldHandle} style={[styles.fieldSurface, { height: config.artHeight, width: config.artWidth }]} />
          </View>
        </View>
      </GestureDetector>

      <View pointerEvents="none" style={styles.footer}>
        <TextView style={styles.footerText}>{config.rows * config.cols} characters</TextView>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  fieldSurface: {
    flex: 1,
  },
  footer: {
    alignItems: 'center',
    bottom: 102,
    left: 0,
    position: 'absolute',
    right: 0,
  },
  footerText: {
    color: 'grey',
    fontFamily: 'Menlo',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.28,
    paddingBottom: 24,
    textAlign: 'center',
  },
  root: {
    backgroundColor: demoTheme.root,
    flex: 1,
    overflow: 'hidden',
  },
  stage: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    paddingBottom: 100,
    paddingHorizontal: 12,
  },
  textField: {
    justifyContent: 'center',
  },
});
