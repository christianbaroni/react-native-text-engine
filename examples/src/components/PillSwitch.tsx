import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { demoTheme } from '../theme/demoTheme';

type Option<T extends string> = {
  label: string;
  value: T;
};

type PillSwitchProps<T extends string> = {
  options: readonly Option<T>[];
  value: T;
  onChange: (value: T) => void;
};

export function PillSwitch<T extends string>({ options, value, onChange }: PillSwitchProps<T>) {
  return (
    <View style={styles.root}>
      {options.map(option => {
        const isActive = option.value === value;
        return (
          <Pressable key={option.value} onPress={() => onChange(option.value)} style={[styles.item, isActive ? styles.itemActive : null]}>
            <Text style={[styles.label, isActive ? styles.labelActive : null]}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  item: {
    alignItems: 'center',
    borderRadius: 999,
    justifyContent: 'center',
    minHeight: 34,
    paddingHorizontal: 14,
  },
  itemActive: {
    backgroundColor: '#171d2a',
  },
  label: {
    color: demoTheme.textTertiary,
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.1,
  },
  labelActive: {
    color: demoTheme.textPrimary,
  },
  root: {
    alignSelf: 'flex-start',
    backgroundColor: '#090d15',
    borderColor: demoTheme.borderStrong,
    borderRadius: 999,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 6,
    padding: 6,
  },
});
