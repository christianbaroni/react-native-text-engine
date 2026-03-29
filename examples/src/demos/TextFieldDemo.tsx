import React, { useLayoutEffect, useMemo } from 'react';
import {
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
  type LayoutChangeEvent,
} from 'react-native';
import { useStableValue } from '@storesjs/stores';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useFrameCallback, useSharedValue } from 'react-native-reanimated';
import type { TextMeasureRun } from 'react-native-pretext';
import { WorkletText } from '../pretext/WorkletText';
import {
  createTextFieldRuntimeInput,
  FIELD_STYLE,
  resolveTextFieldConfig,
  stepTextFieldRuntime,
  type TextFieldPointer,
} from './textFieldEngine';
import { demoTheme } from '../theme/demoTheme';

export function TextFieldDemo({ isActive = true }: { isActive?: boolean }) {
  const { height, width } = useWindowDimensions();
  const config = useMemo(
    () => resolveTextFieldConfig(width, height),
    [height, width],
  );
  const runtimeInput = useMemo(
    () => createTextFieldRuntimeInput(config),
    [config],
  );
  const initialFrame = useMemo(
    () => stepTextFieldRuntime(runtimeInput, 0, { active: false, x: 0, y: 0 }),
    [runtimeInput],
  );

  const active = useSharedValue(isActive ? 1 : 0);
  const fieldText = useSharedValue(initialFrame.text);
  const fieldRuns = useSharedValue<readonly TextMeasureRun[]>(
    initialFrame.runs,
  );
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
  const runtimeInputValue = useSharedValue(runtimeInput);

  useLayoutEffect(() => {
    active.value = isActive ? 1 : 0;
  }, [active, isActive]);

  useLayoutEffect(() => {
    phase.value = 0;
    runtimeInputValue.value = runtimeInput;

    const next = stepTextFieldRuntime(runtimeInput, 0, pointer.value);
    fieldText.value = next.text;
    fieldRuns.value = next.runs;
    fieldFrame.value = {
      height: config.artHeight,
      width: config.artWidth,
      x: 0,
      y: 0,
    };
  }, [
    config.artHeight,
    config.artWidth,
    fieldFrame,
    fieldRuns,
    fieldText,
    phase,
    pointer,
    runtimeInput,
    runtimeInputValue,
  ]);

  const updateFieldFrame = (event: LayoutChangeEvent) => {
    const {
      height: layoutHeight,
      width: layoutWidth,
      x,
      y,
    } = event.nativeEvent.layout;
    fieldFrame.value = { height: layoutHeight, width: layoutWidth, x, y };
  };

  const onFrame = useStableValue(
    () => (frameInfo: { timeSincePreviousFrame: number | null }) => {
      'worklet';

      if (active.value === 0) return;

      phase.value += (frameInfo.timeSincePreviousFrame ?? 16.67) / 1000;

      const next = stepTextFieldRuntime(
        runtimeInputValue.value,
        phase.value,
        pointer.value,
      );
      fieldText.value = next.text;
      fieldRuns.value = next.runs;
    },
  );

  useFrameCallback(onFrame);

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
    [fieldFrame, pointer],
  );

  return (
    <SafeAreaView style={styles.root}>
      <GestureDetector gesture={dragGesture}>
        <View style={styles.stage}>
          <View
            onLayout={updateFieldFrame}
            style={[
              styles.textField,
              { height: config.artHeight, width: config.artWidth },
            ]}>
            <WorkletText
              ellipsizeMode="clip"
              numberOfLines={config.rows}
              runs={fieldRuns}
              style={[
                styles.fieldText,
                {
                  height: config.artHeight,
                  width: config.artWidth,
                },
              ]}>
              {fieldText}
            </WorkletText>
          </View>
        </View>
      </GestureDetector>

      <View pointerEvents="none" style={styles.footer}>
        <Text style={styles.footerText}>
          {config.rows * config.cols} characters
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  fieldText: {
    color: FIELD_STYLE.color,
    fontFamily: FIELD_STYLE.fontFamily,
    fontSize: FIELD_STYLE.fontSize,
    fontWeight: '300',
    letterSpacing: FIELD_STYLE.letterSpacing,
    lineHeight: FIELD_STYLE.lineHeight,
    textAlign: 'center',
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
