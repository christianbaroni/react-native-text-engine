import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: [
      {
        find: 'react-native/Libraries/Utilities/codegenNativeComponent',
        replacement: path.resolve(rootDir, 'tests/mocks/codegenNativeComponent.ts'),
      },
      {
        find: 'react-native',
        replacement: path.resolve(rootDir, 'tests/mocks/react-native.ts'),
      },
      {
        find: 'react-native-worklets',
        replacement: path.resolve(rootDir, 'tests/mocks/react-native-worklets.ts'),
      },
    ],
  },
  test: {
    clearMocks: true,
    environment: 'jsdom',
    restoreMocks: true,
  },
});
