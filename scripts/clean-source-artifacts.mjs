import fs from 'node:fs';
import path from 'node:path';

const packageRoot = process.cwd();
const sourceRoot = path.join(packageRoot, 'src');
const removableExtensions = new Set(['.js', '.jsx', '.map']);

function removeGeneratedSourceArtifacts(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      removeGeneratedSourceArtifacts(entryPath);
      continue;
    }

    if (!removableExtensions.has(path.extname(entry.name))) continue;
    fs.rmSync(entryPath, { force: true });
  }
}

if (fs.existsSync(sourceRoot)) {
  removeGeneratedSourceArtifacts(sourceRoot);
}
