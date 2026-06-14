import jiti from 'jiti';

const createJiti = typeof jiti === 'function' ? jiti : jiti.createJiti;

createJiti(import.meta.url, {
  fsCache: false,
  interopDefault: true,
  moduleCache: false,
})('./sync-text-engine-config.mts');
