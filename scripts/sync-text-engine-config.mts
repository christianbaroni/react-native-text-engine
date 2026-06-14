import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { syncTextEngineDefaults } from './sync-text-engine-config-core.mts';

function readFlag(name: string): string | null {
  const flag = `--${name}`;
  const index = process.argv.indexOf(flag);
  if (index === -1) return null;

  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`RNTextEngine: ${flag} requires a value.`);
  }

  return value;
}

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.resolve(readFlag('package-root') ?? path.join(scriptDir, '..'));
const appRoot = path.resolve(readFlag('app-root') ?? process.cwd());

syncTextEngineDefaults({
  appRoot,
  packageRoot,
});
