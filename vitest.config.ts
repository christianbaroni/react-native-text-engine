import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      'react-native': path.resolve(rootDir, 'tests/mocks/react-native.ts'),
      'react-native-worklets': path.resolve(rootDir, 'tests/mocks/react-native-worklets.ts'),
    },
  },
  test: {
    clearMocks: true,
    environment: 'jsdom',
    restoreMocks: true,
  },
});
