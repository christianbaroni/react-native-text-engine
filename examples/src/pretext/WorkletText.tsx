import React from 'react';
import { Platform, StyleSheet, View, type StyleProp, type TextStyle, type ViewStyle } from 'react-native';
import AnimateableText from 'react-native-animateable-text';
import { TextView, type TextViewProps } from 'react-native-pretext';
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

type WorkletTextProps = {
  children: WorkletTextValue;
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  numberOfLines?: number;
  selectable?: boolean;
  style?: StyleProp<TextStyle>;
  testID?: string;
};

const AnimatedNativeTextView =
  Platform.OS === 'ios' ? Animated.createAnimatedComponent(TextView as React.ComponentType<TextViewProps>) : null;

export function WorkletText({ children, ellipsizeMode, numberOfLines, selectable, style, testID }: WorkletTextProps) {
  const animatedProps = useAnimatedProps(() => {
    const text = typeof children === 'string' ? children : children == null ? '' : (children.value ?? '');

    return { text };
  });

  if (Platform.OS === 'ios') {
    const flattened = StyleSheet.flatten(style) ?? {};
    const containerStyle = buildContainerStyle(flattened);
    const textProps = buildNativeTextProps(flattened);

    if (!AnimatedNativeTextView) return null;

    return (
      <View style={containerStyle}>
        <AnimatedNativeTextView
          animatedProps={animatedProps}
          {...textProps}
          ellipsizeMode={ellipsizeMode}
          numberOfLines={numberOfLines}
          style={styles.fill}
          testID={testID}
        />
      </View>
    );
  }

  return (
    <AnimateableText
      allowFontScaling={false}
      animatedProps={animatedProps}
      ellipsizeMode={ellipsizeMode}
      numberOfLines={numberOfLines}
      selectable={selectable}
      style={style}
      testID={testID}
    />
  );
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

function buildNativeTextProps(style: TextStyle): Omit<TextViewProps, 'ellipsizeMode' | 'numberOfLines' | 'style' | 'text'> {
  return {
    color: typeof style.color === 'string' ? style.color : undefined,
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
