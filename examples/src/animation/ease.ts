import type { EasingType, NoneTransition, SpringTransition, TimingTransition, TransitionMap } from 'react-native-ease';

const DURATION_SPRING_DEFAULT_MASS = 4;
const DURATION_SPRING_ENERGY_THRESHOLD = 6e-9;
const DURATION_SPRING_MAX_STIFFNESS = 8e3;
const PERCEPTUAL_DURATION_MULTIPLIER = 1.5;

type ReanimatedPhysicsSpring = {
  damping: number;
  mass: number;
  stiffness: number;
};

type ReanimatedDurationSpring = {
  dampingRatio: number;
  duration: number;
  mass?: number;
};

type ReanimatedSpring = ReanimatedPhysicsSpring | ReanimatedDurationSpring;
type TimingLikeTransition = TimingTransition | NoneTransition;

function isDurationSpring(config: ReanimatedSpring): config is ReanimatedDurationSpring {
  return 'duration' in config;
}

function bisectRoot({
  fn,
  max,
  maxIterations = 100,
  min = Number.EPSILON,
  precision,
}: {
  fn: (value: number) => number;
  max: number;
  maxIterations?: number;
  min?: number;
  precision: number;
}) {
  let low = min;
  let high = max;
  let current = (low + high) * 0.5;
  const direction = fn(high) >= fn(low) ? 1 : -1;
  let remainingIterations = maxIterations;

  while (Math.abs(fn(current)) > precision && remainingIterations > 0) {
    remainingIterations -= 1;
    if (fn(current) * direction < 0) low = current;
    else high = current;
    current = (low + high) * 0.5;
  }

  return current;
}

function getSpringEnergy(displacement: number, velocity: number, stiffness: number, mass: number) {
  return 0.5 * stiffness * displacement ** 2 + 0.5 * mass * velocity ** 2;
}

function roundConfigValue(value: number) {
  return Math.round(value * 1000) / 1000;
}

function buildSpringFromDuration({
  dampingRatio,
  duration,
  mass = DURATION_SPRING_DEFAULT_MASS,
}: ReanimatedDurationSpring): SpringTransition {
  const targetEnergy = DURATION_SPRING_ENERGY_THRESHOLD;
  const settlingSeconds = (duration * PERCEPTUAL_DURATION_MULTIPLIER) / 1000;
  const precision = targetEnergy * 1e-3;

  const stiffness = bisectRoot({
    fn: currentStiffness => {
      const omega = Math.sqrt(currentStiffness / mass) * dampingRatio;
      const displacement = (1 + omega * settlingSeconds) * Math.exp(-omega * settlingSeconds);
      const velocity = Math.exp(-omega * settlingSeconds) * (omega - omega * (1 + omega * settlingSeconds));
      const currentEnergy = getSpringEnergy(displacement, velocity, currentStiffness, mass);
      const initialEnergy = getSpringEnergy(1, 0, currentStiffness, mass);

      return currentEnergy / initialEnergy - targetEnergy;
    },
    max: DURATION_SPRING_MAX_STIFFNESS,
    precision,
  });

  return {
    type: 'spring',
    damping: roundConfigValue(dampingRatio * 2 * Math.sqrt(stiffness * mass)),
    mass: roundConfigValue(mass),
    stiffness: roundConfigValue(stiffness),
  };
}

function buildSpring(config: ReanimatedSpring): SpringTransition {
  if (isDurationSpring(config)) return buildSpringFromDuration(config);
  return { type: 'spring', ...config };
}

/** Easing values expressible by `react-native-ease`, keeping the old naming surface intact. */
export const EASING = Object.freeze({
  bezier: {
    buttonPress: [0.25, 0.46, 0.45, 0.94],
    fade: [0.22, 1, 0.36, 1],
  },
  in: {
    cubic: [0.55, 0.055, 0.675, 0.19],
    ease: 'easeIn',
    quad: [0.55, 0.085, 0.68, 0.53],
    sin: [0.47, 0, 0.745, 0.715],
  },
  inOut: {
    cubic: [0.645, 0.045, 0.355, 1],
    ease: 'easeInOut',
    quad: [0.455, 0.03, 0.515, 0.955],
    sin: [0.445, 0.05, 0.55, 0.95],
  },
  out: {
    cubic: [0.215, 0.61, 0.355, 1],
    ease: 'easeOut',
    quad: [0.25, 0.46, 0.45, 0.94],
    sin: [0.39, 0.575, 0.565, 1],
  },
} as const satisfies Record<'bezier' | 'in' | 'inOut' | 'out', Record<string, EasingType>>);

/** Spring transitions translated from the previous Reanimated config set. */
export const SPRING_CONFIGS = Object.freeze({
  browserTabTransition: buildSpring({ dampingRatio: 0.82, duration: 800 }),
  keyboardConfig: buildSpring({ damping: 500, mass: 3, stiffness: 1000 }),
  priceChangeConfig: buildSpring({ damping: 30, mass: 0.8, stiffness: 300 }),
  sliderConfig: buildSpring({ damping: 40, mass: 1.25, stiffness: 450 }),
  slowSpring: buildSpring({ damping: 500, mass: 3, stiffness: 800 }),
  snappierSpringConfig: buildSpring({ damping: 42, mass: 0.8, stiffness: 800 }),
  snappyMediumSpringConfig: buildSpring({ damping: 70, mass: 0.8, stiffness: 500 }),
  snappySpringConfig: buildSpring({ damping: 100, mass: 0.8, stiffness: 275 }),
  softerSpringConfig: buildSpring({ damping: 50, mass: 1.2, stiffness: 400 }),
  springConfig: buildSpring({ damping: 100, mass: 1.2, stiffness: 750 }),
  tabGestureConfig: buildSpring({ damping: 36, mass: 1.4, stiffness: 350 }),
  tabSwitchConfig: buildSpring({ damping: 40, mass: 1.25, stiffness: 420 }),
  walletDraggableConfig: buildSpring({ damping: 36, mass: 0.8, stiffness: 800 }),
} as const satisfies Record<string, SpringTransition>);

/** Timing and instant transitions translated from the previous Reanimated config set. */
export const TIMING_CONFIGS = Object.freeze({
  buttonPressConfig: { type: 'timing', duration: 160, easing: EASING.bezier.buttonPress },
  fadeConfig: { type: 'timing', duration: 200, easing: EASING.bezier.fade },
  fastFadeConfig: { type: 'timing', duration: 100, easing: EASING.bezier.fade },
  slowFadeConfig: { type: 'timing', duration: 300, easing: EASING.bezier.fade },
  slowerFadeConfig: { type: 'timing', duration: 400, easing: EASING.bezier.fade },
  slowestFadeConfig: { type: 'timing', duration: 500, easing: EASING.bezier.fade },
  tabPressConfig: { type: 'timing', duration: 800, easing: EASING.bezier.fade },
  zero: { type: 'none' },
} as const satisfies Record<string, TimingLikeTransition>);

export const DEMO_TRANSITIONS = Object.freeze({
  overlayReveal: {
    opacity: TIMING_CONFIGS.fadeConfig,
    transform: SPRING_CONFIGS.snappyMediumSpringConfig,
  },
  selection: {
    backgroundColor: TIMING_CONFIGS.buttonPressConfig,
    default: SPRING_CONFIGS.snappierSpringConfig,
    opacity: TIMING_CONFIGS.fastFadeConfig,
  },
  surfaceReveal: {
    opacity: TIMING_CONFIGS.slowFadeConfig,
    transform: SPRING_CONFIGS.softerSpringConfig,
  },
} as const satisfies Record<string, TransitionMap>);
