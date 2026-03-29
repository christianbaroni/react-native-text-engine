import React from 'react';
import { processColor, StyleSheet, View, type StyleProp, type TextStyle, type ViewStyle } from 'react-native';
import { TextView, type TextMeasureRun } from 'react-native-pretext';
import Animated, { type DerivedValue, type SharedValue, useAnimatedProps } from 'react-native-reanimated';

type SharedTextValue =
  | SharedValue<string>
  | SharedValue<string | null>
  | SharedValue<string | undefined>
  | SharedValue<string | null | undefined>
  | DerivedValue<string>
  | DerivedValue<string | null>
  | DerivedValue<string | undefined>
  | DerivedValue<string | null | undefined>;

export type WorkletTextValue = SharedTextValue | string | null | undefined;
type SharedRunsValue = SharedValue<readonly TextMeasureRun[]> | DerivedValue<readonly TextMeasureRun[]>;
type WorkletTextRuns = SharedRunsValue | readonly TextMeasureRun[] | null | undefined;

type WorkletTextProps = {
  children: WorkletTextValue;
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  numberOfLines?: number;
  runs?: WorkletTextRuns;
  selectable?: boolean;
  style?: StyleProp<TextStyle>;
  testID?: string;
};

const AnimatedNativeTextView = Animated.createAnimatedComponent(TextView as React.ComponentType<Record<string, unknown>>);

export function WorkletText({ children, ellipsizeMode, numberOfLines, runs, selectable, style, testID }: WorkletTextProps) {
  const animatedProps = useAnimatedProps(() => {
    const text = typeof children === 'string' ? children : children == null ? '' : (children.value ?? '');
    const resolvedRuns = resolveRuns(runs);

    return { runs: resolvedRuns, text };
  });

  const flattened = StyleSheet.flatten(style) ?? {};
  const containerStyle = buildContainerStyle(flattened);
  const textProps = buildNativeTextProps(flattened);

  return (
    <View style={containerStyle}>
      <AnimatedNativeTextView
        animatedProps={animatedProps}
        {...textProps}
        ellipsizeMode={ellipsizeMode}
        numberOfLines={numberOfLines}
        selectable={selectable}
        style={styles.fill}
        testID={testID}
      />
    </View>
  );
}

function isSharedRunsValue(runs: WorkletTextRuns): runs is SharedRunsValue {
  'worklet';
  return typeof runs === 'object' && runs !== null && 'value' in runs;
}

function resolveRuns(runs: WorkletTextRuns): readonly TextMeasureRun[] | undefined {
  'worklet';
  if (runs == null) return undefined;
  return isSharedRunsValue(runs) ? runs.value : runs;
}

function buildContainerStyle(style: TextStyle): ViewStyle {
  return {
    alignSelf: style.alignSelf,
    flex: style.flex,
    flexBasis: style.flexBasis,
    flexGrow: style.flexGrow,
    flexShrink: style.flexShrink,
    height: typeof style.height === 'number' ? style.height : undefined,
    marginBottom: style.marginBottom,
    marginLeft: style.marginLeft,
    marginRight: style.marginRight,
    marginTop: style.marginTop,
    maxHeight: typeof style.maxHeight === 'number' ? style.maxHeight : undefined,
    maxWidth: typeof style.maxWidth === 'number' ? style.maxWidth : undefined,
    minHeight: typeof style.minHeight === 'number' ? style.minHeight : undefined,
    minWidth: typeof style.minWidth === 'number' ? style.minWidth : undefined,
    width: typeof style.width === 'number' ? style.width : undefined,
  };
}

function buildNativeTextProps(style: TextStyle): Record<string, unknown> {
  return {
    color: style.color == null ? undefined : processColor(style.color),
    fontFamily: style.fontFamily,
    fontSize: typeof style.fontSize === 'number' ? style.fontSize : undefined,
    fontStyle: style.fontStyle,
    fontWeight: typeof style.fontWeight === 'string' ? style.fontWeight : undefined,
    letterSpacing: style.letterSpacing,
    lineHeight: style.lineHeight,
    textAlign: style.textAlign,
  };
}

const styles = StyleSheet.create({
  fill: {
    flex: 1,
  },
});
