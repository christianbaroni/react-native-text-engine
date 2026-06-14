module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    'react-native-text-engine/babel-plugin',
    [
      'react-native-worklets/plugin',
      {
        bundleMode: true,
        workletizableModules: ['react-native-text-engine/worklets', 'src/worklet-list'],
      },
    ],
  ],
};
