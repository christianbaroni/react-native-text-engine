// https://github.com/react-native-community/cli/blob/main/docs/dependencies.md

module.exports = {
  dependency: {
    platforms: {
      /**
       * @type {import('@react-native-community/cli-types').IOSDependencyParams}
       */
      ios: {
        scriptPhases: [
          {
            execution_position: 'before_compile',
            name: 'RNTextEngine sync config',
            path: './scripts/sync-text-engine-config.sh',
          },
        ],
      },
      /**
       * @type {import('@react-native-community/cli-types').AndroidDependencyParams}
       */
      android: {},
    },
  },
};
