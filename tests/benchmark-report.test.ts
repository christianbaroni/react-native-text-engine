// @vitest-environment node
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, it, onTestFinished } from 'vitest';
import { parseRun, renderComparison, updateResults } from '../benchmarks/report.mjs';

type Platform = 'ios' | 'android';

const workloads = {
  fabric_chat_shadow_tree_layout: 512,
  fabric_mount_and_first_draw: 512,
  retained_paragraph_measurement: 16384,
  cold_short_label_layout: 512,
  cold_uniform_chat_layout: 512,
  cached_uniform_layout_queries: 98304,
  cached_truncated_layout_queries: 98304,
  cold_rich_inline_layout: 384,
};

const metadata = {
  startedAt: '2026-09-19T12:00:00Z',
  reactNativeVersion: '0.84.1',
  textEngineVersion: '0.2.0',
  revision: 'test-revision',
  sourceHash: 'test-checksum',
  relativeRunDirectory: '.results/test',
  cpu: 'Test CPU',
  hostOS: 'Test OS',
  architecture: 'arm64',
  node: 'v22.21.1',
  xcode: 'Xcode 26.3',
};

function runLog(run: number, platform: Platform, scale = 1, { sdk = 'iphonesimulator26.2', prepared = false, implementation = 'RN Text' } = {}): string {
  const meta = {
    run,
    pid: 1000 + run + (prepared ? 10 : 0) + (implementation === 'TextView' ? 100 : 0),
    implementation,
    platform,
    deviceName: 'Test device',
    osVersion: '26.2',
    configuration: 'Release',
    host: 'native-only',
    geometryValidated: true,
    samples: 9,
    warmups: platform === 'ios' ? 2 : 10,
    includesAutoreleasePoolDrain: true,
    sdk,
    enablePreparedTextLayout: prepared,
    disableTextLayoutManagerCacheAndroid: false,
    preparedTextCacheSize: 200,
    apiLevel: 34,
    abi: 'arm64-v8a',
    density: 2,
  };
  const records = Object.entries(workloads).flatMap(([scenario, operations]) =>
    (platform === 'android' ? [implementation] : ['RN Text', 'TextView']).map(implementation => ({
      scenario,
      operations: platform === 'android' && scenario.startsWith('cached_') ? 6144 : operations,
      implementation,
      samplesMs: [1, 9, 3, 7, 5, 8, 2, 4, 100].map(value => value * scale * (implementation === 'RN Text' ? 2 : 1)),
    }))
  );
  return [
    `RNTEXT_BENCHMARK_META ${JSON.stringify(meta)}`,
    ...records.map(record => `RNTEXT_BENCHMARK_RESULT ${JSON.stringify(record)}`),
    platform === 'ios' ? '** TEST SUCCEEDED **' : 'OK (1 test)\nINSTRUMENTATION_CODE: -1',
  ].join('\n');
}

it.each(['iphonesimulator26.2', 'iphoneos26.2'])('reports %s measurements with dispersion and unfiltered samples', sdk => {
  const report = renderComparison(
    metadata,
    [1, 4, 10].map((scale, index) => runLog(index + 1, 'ios', scale, { sdk }))
  );
  expect(report).toContain(`${sdk.startsWith('iphonesimulator') ? 'Test device simulator' : 'Test device'}, iOS 26.2.`);
  expect(report).toContain(`SDK ${sdk};`);
  expect(report).toContain('| Chat list layout | 512 | 40.000 ± 30.000 | 20.000 ± 15.000 | 0.500× |');
  expect(report).toContain(
    '| Chat list layout | RN Text | 1 | 2.000000, 18.000000, 6.000000, 14.000000, 10.000000, 16.000000, 4.000000, 8.000000, 200.000000 |'
  );
  expect(report.split('\n').filter(line => /\| (RN Text|TextView) \| [123] \|/.test(line))).toHaveLength(48);
});

it('requires isolated Android processes for each implementation and layout configuration', () => {
  const androidMetadata = { ...metadata, platform: 'android', compilation: 'speed', apkSha256: 'a'.repeat(64) };
  const logs = [false, true].flatMap(prepared =>
    ['RN Text', 'TextView'].flatMap(implementation =>
      (prepared ? [2, 6, 12] : [1, 4, 10]).map((scale, index) => runLog(index + 1, 'android', scale, { prepared, implementation }))
    )
  );
  const report = renderComparison(androidMetadata, logs);
  expect(report).toContain('### RN Text with default layout');
  expect(report).toContain('### RN Text with prepared layout');
  expect(report).toContain('| Chat list layout | 512 | 40.000 ± 30.000 | 20.000 ± 15.000 | 0.500× |');
  expect(report).toContain('| Chat list layout | 512 | 60.000 ± 40.000 | 30.000 ± 20.000 | 0.500× |');
  expect(report).toContain('| Manager queries, 768 keys | 6,144 |');
  expect(report.split('\n').filter(line => /\| (Default|Prepared) \| [123] \|/.test(line))).toHaveLength(96);
  expect(() => renderComparison(androidMetadata, logs.slice(0, 3))).toThrow();
  expect(() =>
    renderComparison(
      androidMetadata,
      logs.map(log => log.replace('"enablePreparedTextLayout":true', '"enablePreparedTextLayout":false'))
    )
  ).toThrow();
  const log = runLog(1, 'android');
  expect(() => parseRun(log.replace('"implementation":"RN Text"', '"implementation":"TextView"'), 1, 'android')).toThrow();
  expect(() => parseRun(log.replace('"preparedTextCacheSize":200', '"preparedTextCacheSize":1024'), 1, 'android')).toThrow();
  expect(() => parseRun(log.replace('"operations":6144', '"operations":98304'), 1, 'android')).toThrow();
});

it.each<Platform>(['ios', 'android'])('rejects failed %s runs even when the log also reports success', platform => {
  const log = runLog(1, platform);
  expect(() => parseRun(log, 1, platform)).not.toThrow();
  const failures = platform === 'ios' ? ['** TEST FAILED **'] : ['INSTRUMENTATION_STATUS_CODE: -2', 'INSTRUMENTATION_CODE: 0'];
  for (const failure of failures) {
    expect(() => parseRun(log + '\n' + failure, 1, platform)).toThrow();
  }
});

it.each<Platform>(['ios', 'android'])('replaces only the latest %s results', platform => {
  const directory = mkdtempSync(join(tmpdir(), 'rnte-report-'));
  onTestFinished(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'results.md');
  const original = '# Results\n\n## iOS\n\nOld iOS\n\n## Android\n\nOld Android\n';
  const name = platform === 'ios' ? 'iOS' : 'Android';
  writeFileSync(path, original);
  updateResults(path, `## ${name}\n\nFirst run`, platform);
  updateResults(path, `## ${name}\n\nLatest run`, platform);
  expect(readFileSync(path, 'utf8')).toBe(original.replace(`Old ${name}`, 'Latest run'));
});
