const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { wrapWithReanimatedMetroConfig } = require('react-native-reanimated/metro-config');
const { bundleModeMetroConfig } = require('react-native-worklets/bundleMode');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const appNodeModules = path.resolve(__dirname, 'node_modules');
const packageRoot = path.resolve(__dirname, '..');
const packageNodeModules = path.resolve(packageRoot, 'node_modules');
const localEaseRoot = '/Users/christian/dev/react-native-ease';
const runtimePeerPackages = ['react', 'react-native', 'react-native-reanimated', 'react-native-worklets'];
const escapePathForRegex = value => value.replace(/[|\\{}()[\]^$+*?.-]/g, '\\$&');
const appDefaultsOverlayPath = path.resolve(__dirname, 'generated/react-native-text-engine/TextEngineAppDefaults.js');
const textEngineDefaultsModuleName = './generated/TextEngineAppDefaults';
const textEnginePackageModuleRoots = [
  path.join(packageRoot, 'src'),
  path.join(packageRoot, 'lib/module'),
  path.join(packageRoot, 'lib/commonjs'),
];
const bundleModeResolveRequest = bundleModeMetroConfig.resolver.resolveRequest;

function buildRuntimePeerAliases(nodeModulesRoot) {
  return Object.fromEntries(runtimePeerPackages.map(packageName => [packageName, path.resolve(nodeModulesRoot, packageName)]));
}

function buildDuplicateRuntimePeerBlockList(nodeModulesRoot) {
  return runtimePeerPackages.map(packageName => new RegExp(`${escapePathForRegex(path.join(nodeModulesRoot, packageName))}/.*`));
}

function isInsidePath(parentPath, candidatePath) {
  const relativePath = path.relative(parentPath, candidatePath);
  return relativePath === '' || (!relativePath.startsWith('..') && !path.isAbsolute(relativePath));
}

function resolveRequest(context, moduleName, platform) {
  const originModulePath = context.originModulePath ? path.resolve(context.originModulePath) : '';

  if (moduleName === textEngineDefaultsModuleName && textEnginePackageModuleRoots.some(root => isInsidePath(root, originModulePath))) {
    return { type: 'sourceFile', filePath: appDefaultsOverlayPath };
  }

  return bundleModeResolveRequest(context, moduleName, platform);
}

const externalNodeModulesRoots = [packageNodeModules, path.join(localEaseRoot, 'node_modules')];

const config = {
  resolver: {
    blockList: externalNodeModulesRoots.flatMap(buildDuplicateRuntimePeerBlockList),
    extraNodeModules: buildRuntimePeerAliases(appNodeModules),
    nodeModulesPaths: [appNodeModules, packageNodeModules],
    resolveRequest,
    unstable_enableSymlinks: true,
  },
  watchFolders: [packageRoot, localEaseRoot],
};

module.exports = wrapWithReanimatedMetroConfig(mergeConfig(getDefaultConfig(__dirname), bundleModeMetroConfig, config));
