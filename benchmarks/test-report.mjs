import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { parseRun, renderComparison, updateResults } from './report.mjs';

const workloads = [
  ['fabric_chat_shadow_tree_layout', 512],
  ['cold_uniform_chat_layout', 512],
  ['cached_uniform_layout_queries', 98304],
  ['cached_truncated_layout_queries', 98304],
  ['cold_rich_inline_layout', 384],
];
const metadata = {
  startedAt: '2026-09-19T12:00:00Z',
  revision: 'fixture-revision',
  sourceHash: 'fixture-source-hash',
  reactNativeVersion: '0.84.0',
  textEngineVersion: '0.2.0',
  macos: '26.3',
  cpu: 'test CPU',
  architecture: 'arm64',
  node: 'v22.21.1',
  xcode: 'Xcode 26.3\nBuild 17C529',
  sdk: '26.2',
  relativeRunDirectory: '.results/test',
};

function runLog(run, change = () => {}) {
  const meta = {
    run,
    pid: 1000 + run,
    configuration: 'Release',
    host: 'native-only',
    geometryValidated: true,
    warmups: 2,
    samples: 9,
    includesAutoreleasePoolDrain: true,
    deviceName: 'test simulator',
    osVersion: '26.2',
  };
  const records = workloads.flatMap(([scenario, operations]) =>
    ['RN Text', 'TextView'].map(implementation => ({
      scenario,
      operations,
      implementation,
      samplesMs: Array.from({ length: 9 }, (_, i) => (i + 1) * run * (implementation === 'RN Text' ? 2 : 1)),
    }))
  );
  change(meta, records);
  return [
    `RNTEXT_BENCHMARK_META ${JSON.stringify(meta)}`,
    ...records.map(record => `RNTEXT_BENCHMARK_RESULT ${JSON.stringify(record)}`),
    '** TEST SUCCEEDED **',
  ].join('\n');
}

const logs = () => [1, 2, 3].map(run => runLog(run));

test('computes medians and dispersion across processes and preserves all samples', () => {
  const section = renderComparison(metadata, logs());
  assert.match(section, /512 \| 20\.000 ± 10\.000 \| 10\.000 ± 5\.000 \| 0\.500×/);
  assert.equal(section.split('\n').filter(line => /\| (RN Text|TextView) \| [123] \|/.test(line)).length, 30);
  assert.match(section, /3\.000000, 6\.000000, 9\.000000/);
});

for (const [name, mutate] of [
  ['missing row', (_, rows) => rows.pop()],
  [
    'duplicate row',
    (_, rows) => {
      rows[1] = rows[0];
    },
  ],
  [
    'unknown scenario',
    (_, rows) => {
      rows[0].scenario = 'unexpected';
    },
  ],
  [
    'unequal work',
    (_, rows) => {
      rows[0].operations = 1;
    },
  ],
  ['missing sample', (_, rows) => rows[0].samplesMs.pop()],
  [
    'non-finite sample',
    (_, rows) => {
      rows[0].samplesMs[0] = Infinity;
    },
  ],
  [
    'non-numeric sample',
    (_, rows) => {
      rows[0].samplesMs[0] = '1';
    },
  ],
  [
    'zero sample',
    (_, rows) => {
      rows[0].samplesMs[0] = 0;
    },
  ],
  [
    'wrong run order',
    meta => {
      meta.run = 2;
    },
  ],
  [
    'Debug build',
    meta => {
      meta.configuration = 'Debug';
    },
  ],
  [
    'unchecked geometry',
    meta => {
      meta.geometryValidated = false;
    },
  ],
  [
    'active demo host',
    meta => {
      meta.host = 'demo';
    },
  ],
  [
    'incomplete warmup',
    meta => {
      meta.warmups = 1;
    },
  ],
  [
    'missing cleanup cost',
    meta => {
      meta.includesAutoreleasePoolDrain = false;
    },
  ],
]) {
  test(`rejects ${name}`, () => assert.throws(() => parseRun(runLog(1, mutate), 1)));
}

test('rejects failed, partial, malformed, or duplicate metadata output', () => {
  const log = runLog(1);
  assert.equal(parseRun(log.replace('TEST SUCCEEDED', 'TEST EXECUTE SUCCEEDED'), 1).records.length, 10);
  assert.throws(() => parseRun(log.replace('TEST SUCCEEDED', 'TEST FAILED'), 1));
  assert.throws(() => parseRun(log.replace('TEST SUCCEEDED', 'TEST EXECUTE FAILED'), 1));
  assert.throws(() => parseRun(log.replace('TEST SUCCEEDED', 'TEST BUILD SUCCEEDED'), 1));
  assert.throws(() => parseRun(log + '\n** TEST FAILED **', 1));
  assert.throws(() => parseRun(log + '\nRNTEXT_BENCHMARK_RESULT {', 1));
  assert.throws(() => parseRun(log + '\n' + log.split('\n')[0], 1));
});

test('rejects reused processes, changed simulators, and incomplete run sets', () => {
  assert.throws(() => renderComparison(metadata, logs().slice(1)));
  assert.throws(() =>
    renderComparison(metadata, [
      runLog(1),
      runLog(2, meta => {
        meta.pid = 1001;
      }),
      runLog(3),
    ])
  );
  assert.throws(() =>
    renderComparison(metadata, [
      runLog(1),
      runLog(2, meta => {
        meta.osVersion = '25';
      }),
      runLog(3),
    ])
  );
});

test('updates only the marked section; rejected reports preserve existing results', t => {
  const directory = mkdtempSync(join(os.tmpdir(), 'rnte-report-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'results.md');
  const original = 'Introduction\n<!-- BEGIN IOS TEXT COMPARISON -->\nold\n<!-- END IOS TEXT COMPARISON -->\nHistorical results\n';
  writeFileSync(path, original);
  assert.throws(() => updateResults(path, renderComparison(metadata, logs().slice(1))));
  assert.equal(readFileSync(path, 'utf8'), original);
  updateResults(path, renderComparison(metadata, logs()));
  const updated = readFileSync(path, 'utf8');
  assert(updated.startsWith('Introduction\n<!-- BEGIN IOS TEXT COMPARISON -->\n\n## September 19, 2026'));
  assert(updated.endsWith('<!-- END IOS TEXT COMPARISON -->\nHistorical results\n'));
  for (const broken of [
    original.replace('BEGIN', 'MISSING'),
    original + '<!-- END IOS TEXT COMPARISON -->',
    '<!-- END IOS TEXT COMPARISON -->\n<!-- BEGIN IOS TEXT COMPARISON -->',
  ]) {
    writeFileSync(path, broken);
    assert.throws(() => updateResults(path, 'replacement'));
    assert.equal(readFileSync(path, 'utf8'), broken);
  }
});
