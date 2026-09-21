import type { TransformOptions } from '@babel/core';

module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['./babel-plugin.js'],
} satisfies TransformOptions;
