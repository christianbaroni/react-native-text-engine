import React from 'react';
import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { PreparedTextView, type PreparedTextViewProps } from 'react-native-pretext';
import Animated, { type DerivedValue, type SharedValue, useAnimatedProps } from 'react-native-reanimated';

type HandleValue = SharedValue<number> | DerivedValue<number>;

const AnimatedPreparedTextView = Animated.createAnimatedComponent(PreparedTextView as React.ComponentType<PreparedTextViewProps>);

type PreparedHandleTextProps = {
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  handle: HandleValue;
  numberOfLines?: number;
  selectable?: boolean;
  style?: StyleProp<ViewStyle>;
};

export function PreparedHandleText({ ellipsizeMode, handle, numberOfLines, selectable, style }: PreparedHandleTextProps) {
  const animatedProps = useAnimatedProps(() => ({
    handle: handle.value,
  }));

  return (
    <View style={style}>
      <AnimatedPreparedTextView
        animatedProps={animatedProps}
        ellipsizeMode={ellipsizeMode}
        numberOfLines={numberOfLines}
        selectable={selectable}
        style={styles.fill}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  fill: {
    flex: 1,
  },
});
