const path = require('path');
const exclusionList = require('metro-config/private/defaults/exclusionList').default;
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { wrapWithReanimatedMetroConfig } = require('react-native-reanimated/metro-config');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const appNodeModules = path.resolve(__dirname, 'node_modules');
const packageRoot = path.resolve(__dirname, '..');
const packageNodeModules = path.resolve(packageRoot, 'node_modules');
const duplicatePackageNames = ['react', 'react-native', 'react-native-reanimated', 'react-native-worklets'];
const escapePathForRegex = value => value.replace(/[|\\{}()[\]^$+*?.-]/g, '\\$&');
const config = {
  resolver: {
    blockList: exclusionList(
      duplicatePackageNames.map(packageName => new RegExp(`${escapePathForRegex(path.join(packageNodeModules, packageName))}/.*`))
    ),
    extraNodeModules: {
      react: path.resolve(appNodeModules, 'react'),
      'react-native': path.resolve(appNodeModules, 'react-native'),
      'react-native-reanimated': path.resolve(appNodeModules, 'react-native-reanimated'),
      'react-native-worklets': path.resolve(appNodeModules, 'react-native-worklets'),
    },
    nodeModulesPaths: [appNodeModules, packageNodeModules],
    unstable_enableSymlinks: true,
  },
  watchFolders: [packageRoot],
};

module.exports = wrapWithReanimatedMetroConfig(mergeConfig(getDefaultConfig(__dirname), config));
