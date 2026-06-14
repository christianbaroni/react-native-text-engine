import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { EaseView } from 'react-native-ease';
import { Pressable } from 'react-native-gesture-handler';
import { demoTheme } from '../theme/demoTheme';
import { LiquidGlassView } from '@callstack/liquid-glass';
import { DEMO_TRANSITIONS } from '../animation/ease';
import { IS_IOS } from '../constants';

type Option<T extends string> = {
  label: string;
  value: T;
};

type PillSwitchProps<T extends string> = {
  options: readonly Option<T>[];
  value: T;
  onChange: (value: T) => void;
};

const ACTIVE_ITEM_BG = 'rgba(255, 255, 255, 0.06)';
const INACTIVE_ITEM_BG = 'rgba(255, 255, 255, 0)';

const LiquidGlass = IS_IOS ? LiquidGlassView : View;

export function PillSwitch<T extends string>({ options, value, onChange }: PillSwitchProps<T>) {
  return (
    <LiquidGlass style={styles.root}>
      {options.map(option => {
        const isActive = option.value === value;
        return (
          <EaseView
            key={option.value}
            animate={{
              backgroundColor: isActive ? ACTIVE_ITEM_BG : INACTIVE_ITEM_BG,
              scale: isActive ? 1 : 0.985,
            }}
            transition={DEMO_TRANSITIONS.selection}
            style={styles.itemFrame}
          >
            <Pressable onPress={() => onChange(option.value)} style={styles.item}>
              <Text style={[styles.label, isActive ? styles.labelActive : null]}>{option.label}</Text>
            </Pressable>
          </EaseView>
        );
      })}
    </LiquidGlass>
  );
}

const styles = StyleSheet.create({
  itemFrame: {
    borderCurve: 'continuous',
    borderRadius: 999,
    overflow: 'hidden',
  },
  item: {
    alignItems: 'center',
    borderCurve: 'continuous',
    borderRadius: 999,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: 18,
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
    alignItems: 'center',
    backgroundColor: IS_IOS ? undefined : `rgba(20, 14, 10, ${IS_IOS ? 0.6 : 0.78})`,
    borderColor: IS_IOS ? undefined : demoTheme.borderStrong,
    borderCurve: 'continuous',
    borderRadius: 999,
    borderWidth: IS_IOS ? 0 : 1,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center',
    padding: 8,
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: IS_IOS ? 0.52 : 0,
    shadowRadius: 12,
  },
});
