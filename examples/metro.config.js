const path = require('path');
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
const runtimePeerPackages = ['react', 'react-native', 'react-native-reanimated', 'react-native-worklets'];
const escapePathForRegex = value => value.replace(/[|\\{}()[\]^$+*?.-]/g, '\\$&');

function buildRuntimePeerAliases(nodeModulesRoot) {
  return Object.fromEntries(runtimePeerPackages.map(packageName => [packageName, path.resolve(nodeModulesRoot, packageName)]));
}

function buildDuplicateRuntimePeerBlockList(nodeModulesRoot) {
  return runtimePeerPackages.map(packageName => new RegExp(`${escapePathForRegex(path.join(nodeModulesRoot, packageName))}/.*`));
}

const config = {
  resolver: {
    blockList: buildDuplicateRuntimePeerBlockList(packageNodeModules),
    extraNodeModules: buildRuntimePeerAliases(appNodeModules),
    nodeModulesPaths: [appNodeModules, packageNodeModules],
    unstable_enableSymlinks: true,
  },
  watchFolders: [packageRoot],
};

module.exports = wrapWithReanimatedMetroConfig(mergeConfig(getDefaultConfig(__dirname), config));
