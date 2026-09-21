import type { TransformOptions } from '@babel/core';

module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    'react-native-text-engine/babel-plugin',
    [
      'react-native-worklets/plugin',
      {
        bundleMode: true,
        importForwarding: {
          moduleNames: ['react-native-text-engine/worklets'],
          relativePaths: ['src/worklet-list'],
        },
      },
    ],
  ],
} satisfies TransformOptions;
