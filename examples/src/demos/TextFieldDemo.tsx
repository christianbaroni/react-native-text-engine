import React, { useEffect, useLayoutEffect, useMemo } from 'react';
import { StyleSheet, Text, View, useWindowDimensions, type LayoutChangeEvent } from 'react-native';
import { useStableValue } from '@storesjs/stores';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useFrameCallback, useSharedValue } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GlyphFieldView, createGlyphField } from 'react-native-pretext';
import { installPretextInUIRuntime, updateGlyphFieldInRuntime } from 'react-native-pretext/worklets';
import {
  FIELD_STYLE,
  FIELD_VARIANTS,
  createTextFieldFrameBuffer,
  createTextFieldRuntimeInput,
  resolveTextFieldConfig,
  stepTextFieldRuntime,
  type TextFieldFrameBuffer,
  type TextFieldPointer,
} from './textFieldEngine';
import { demoTheme } from '../theme/demoTheme';

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
        letterSpacing: FIELD_STYLE.letterSpacing,
        lineHeight: FIELD_STYLE.lineHeight ?? 20,
        rows: config.rows,
        textAlign: 'center',
        variants: FIELD_VARIANTS,
      }),
    [config.cols, config.rows]
  );

  const active = useSharedValue(isActive ? 1 : 0);
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

  useEffect(() => {
    installPretextInUIRuntime();
  }, []);

  useEffect(() => () => field.release(), [field]);

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

    const frame = stepTextFieldRuntime(runtimeInput, frameBuffer, 0, { active: false, x: 0, y: 0 });
    field.update(frame.glyphs, frame.variantIndices);
  }, [config.artHeight, config.artWidth, field, fieldFrame, frameBuffer, phase, runtimeInput]);

  const updateFieldFrame = (event: LayoutChangeEvent) => {
    const info = event.nativeEvent.layout;
    fieldFrame.value = { height: info.height, width: info.width, x: info.x, y: info.y };
  };

  useFrameCallback(frameInfo => {
    if (active.value === 0) return;
    phase.value += (frameInfo.timeSincePreviousFrame ?? 16.67) / 1000;
    const frame = stepTextFieldRuntime(runtimeInput, frameBuffer, phase.value, pointer.value);
    updateGlyphFieldInRuntime(fieldHandle, frame.glyphs, frame.variantIndices);
  });

  const dragGesture = useMemo(
    () =>
      Gesture.Pan()
        .minDistance(0)
        .onBegin(event => {
          const frame = fieldFrame.value;
          pointer.value = {
            active: true,
            x: event.x - frame.x,
            y: event.y - frame.y,
          };
        })
        .onChange(event => {
          const frame = fieldFrame.value;
          pointer.value = {
            active: true,
            x: event.x - frame.x,
            y: event.y - frame.y,
          };
        })
        .onFinalize(() => {
          pointer.value = {
            active: false,
            x: pointer.value.x,
            y: pointer.value.y,
          };
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
        <Text style={styles.footerText}>{config.rows * config.cols} characters</Text>
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
    color: demoTheme.textSecondary,
    fontFamily: 'Menlo',
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.28,
    lineHeight: 15,
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
