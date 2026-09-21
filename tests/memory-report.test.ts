// @vitest-environment node
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, it, onTestFinished } from 'vitest';
import { parseMemoryRun, renderMemoryResults, updateMemoryResults } from '../benchmarks/memory-report.mts';

type Platform = 'ios' | 'android';
type Suite = 'rn-text' | 'library';

function fixture(run: number, platform: Platform, implementation = 'RN Text', prepared = false, suite: Suite = 'rn-text') {
  const definitions =
    suite === 'rn-text'
      ? [
          ['laid_out_chat', 128],
          ['mounted_chat', 128],
        ]
      : [
          ['prepared_chat', 128],
          ['glyph_fields', 64],
        ];
  const scale = [1, 4, 10][run - 1] ?? 1;
  const snapshot = (delta: number) => ({
    nativeHeapBytes: Math.round(1024 * (1000 + delta)),
    [platform === 'ios' ? 'footprintBytes' : 'managedHeapBytes']: Math.round(1024 * (2000 + delta)),
  });
  return definitions.map(([scenario, units]) => ({
    suite,
    scenario,
    units,
    platform,
    implementation,
    prepared,
    run,
    warmups: 2,
    configuration: 'Release',
    pid: 1000 + run + 10 * ['RN Text', 'TextView', 'PreparedTextView', 'Text Engine'].indexOf(implementation) + (prepared ? 100 : 0),
    deviceName: 'Test device',
    osVersion: '26.2',
    simulator: true,
    scale: 3,
    apiLevel: 34,
    abi: 'arm64-v8a',
    density: 2,
    samples: [1, 2, 3, 4, 5].map(value => ({
      baseline: snapshot(0),
      retained: snapshot((scale * value) / 3),
      released: snapshot((-scale * value) / 3),
    })),
  }));
}

function log(records: unknown[], platform: Platform) {
  return (
    records.map(record => `RNTEXT_MEMORY_RESULT ${JSON.stringify(record)}`).join('\n') +
    '\n' +
    (platform === 'ios' ? '** TEST EXECUTE SUCCEEDED **' : 'OK (1 test)\nINSTRUMENTATION_CODE: -1')
  );
}

const metadata = {
  startedAt: '2026-09-21T12:00:00Z',
  reactNativeVersion: '0.87.1',
  textEngineVersion: '0.3.1',
  revision: 'fixture',
  sourceHash: 'hash',
};
function campaign(suite: Suite, platform: Platform) {
  const directory = mkdtempSync(join(tmpdir(), 'rnte-memory-'));
  onTestFinished(() => rmSync(directory, { recursive: true, force: true }));
  const implementations =
    suite === 'library'
      ? [['engine', 'Text Engine']]
      : [
          ['rn', 'RN Text'],
          ['textview', 'TextView'],
          ['preparedtextview', 'PreparedTextView'],
        ];
  for (const prepared of suite === 'rn-text' && platform === 'android' ? [false, true] : [false]) {
    for (const [key, name] of implementations) {
      for (const run of [1, 2, 3]) {
        const file =
          suite === 'library'
            ? `memory-${run}.log`
            : platform === 'ios'
              ? `memory-${run}-${key}.log`
              : `memory-${run}-${prepared ? 'prepared' : 'default'}-${key}.log`;
        writeFileSync(join(directory, file), log(fixture(run, platform, name, prepared, suite), platform));
      }
    }
  }
  return directory;
}

it.each<Platform>(['ios', 'android'])('validates all memory snapshots on %s', platform => {
  const records = fixture(1, platform);
  const source = log(records, platform);
  expect(parseMemoryRun(source, 1, 'rn-text', platform, 'RN Text', false)).toHaveLength(2);
  expect(() => parseMemoryRun(log(records.slice(1), platform), 1, 'rn-text', platform, 'RN Text', false)).toThrow('Incomplete');
  expect(() => parseMemoryRun(log([records[0], records[0]], platform), 1, 'rn-text', platform, 'RN Text', false)).toThrow('Duplicate');
  expect(() => parseMemoryRun(source.replace('"units":128', '"units":127'), 1, 'rn-text', platform, 'RN Text', false)).toThrow(
    'object count'
  );
  expect(() => parseMemoryRun(source.replace('1024000', '-1'), 1, 'rn-text', platform, 'RN Text', false)).toThrow('counter');
  expect(() => parseMemoryRun(source.replace('"baseline":', '"missing":'), 1, 'rn-text', platform, 'RN Text', false)).toThrow();
  expect(() =>
    parseMemoryRun(
      source + '\n' + (platform === 'ios' ? '** TEST FAILED **' : 'INSTRUMENTATION_CODE: 0'),
      1,
      'rn-text',
      platform,
      'RN Text',
      false
    )
  ).toThrow();
});

it.each<[Suite, Platform]>([
  ['rn-text', 'ios'],
  ['rn-text', 'android'],
  ['library', 'ios'],
  ['library', 'android'],
])('summarizes %s/%s without discarding negative changes', (suite, platform) => {
  const directory = campaign(suite, platform);
  const report = renderMemoryResults({ ...metadata, platform }, directory, suite);
  expect(report).toContain('4.0 ± 3.0');
  expect(report).toContain('-4.0 ± 3.0');
  expect(report).toContain('Memory snapshots (bytes)');
  expect(report.includes('Source checksum')).toBe(suite === 'rn-text');
  expect(report).toContain(platform === 'ios' ? 'Process footprint' : 'Managed heap');
  expect(report).toContain(suite === 'library' ? '64 independent 80 × 24 glyph fields' : '128 drawn views and their paragraphs');
  const file = suite === 'library' ? 'memory-2.log' : platform === 'ios' ? 'memory-2-rn.log' : 'memory-2-default-rn.log';
  const path = join(directory, file);
  const original = readFileSync(path, 'utf8');
  writeFileSync(path, original.replaceAll('"pid":1002', '"pid":1001').replaceAll('"pid":1032', '"pid":1031'));
  expect(() => renderMemoryResults({ ...metadata, platform }, directory, suite)).toThrow('fresh processes');
  rmSync(path);
  expect(() => renderMemoryResults({ ...metadata, platform }, directory, suite)).toThrow();
});

it('preserves timing results and the other platform during memory-only updates', () => {
  const directory = campaign('library', 'ios');
  const path = join(directory, 'results.md');
  writeFileSync(path, '# Results\n\n## iOS\n\nExisting timing\n\n## Android\n\nOther timing\n');
  updateMemoryResults(path, '### Memory\n\nFirst memory run', 'ios');
  updateMemoryResults(path, '### Memory\n\nLatest memory run', 'ios');
  expect(readFileSync(path, 'utf8')).toBe(
    '# Results\n\n## iOS\n\nExisting timing\n\n### Memory\n\nLatest memory run\n\n## Android\n\nOther timing\n'
  );
});
