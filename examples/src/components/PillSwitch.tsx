import React from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
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
    <View style={styles.shell}>
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
    </View>
  );
}

const styles = StyleSheet.create({
  item: {
    alignItems: 'center',
    borderCurve: 'continuous',
    borderRadius: 999,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: 18,
  },
  itemActive: {
    backgroundColor: 'rgba(247, 232, 204, 0.14)',
    borderColor: 'rgba(255, 241, 214, 0.16)',
    borderWidth: 1,
    shadowColor: '#f6ddb6',
    shadowOffset: { height: 8, width: 0 },
    shadowOpacity: Platform.OS === 'ios' ? 0.16 : 0,
    shadowRadius: 18,
  },
  label: {
    color: demoTheme.textSecondary,
    fontSize: 14,
    fontWeight: '700',
    letterSpacing: 0.15,
  },
  labelActive: {
    color: demoTheme.textPrimary,
  },
  root: {
    backgroundColor: 'rgba(20, 14, 10, 0.78)',
    borderColor: demoTheme.borderStrong,
    borderCurve: 'continuous',
    borderRadius: 999,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    overflow: 'hidden',
    padding: 8,
  },
  shell: {
    backgroundColor: 'rgba(255, 246, 227, 0.04)',
    borderColor: 'rgba(255, 239, 212, 0.08)',
    borderCurve: 'continuous',
    borderRadius: 999,
    borderWidth: 1,
    overflow: 'hidden',
    padding: 4,
    shadowColor: '#000000',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: Platform.OS === 'ios' ? 0.22 : 0,
    shadowRadius: 28,
  },
});
