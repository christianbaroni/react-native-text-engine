import { createJiti } from 'jiti';

createJiti(import.meta.url, {
  fsCache: false,
  interopDefault: true,
  moduleCache: false,
})('./sync-text-engine-config.mts');
