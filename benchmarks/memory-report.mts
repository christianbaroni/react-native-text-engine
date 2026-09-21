import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { assertRunSucceeded, median, updateResults, type Platform } from './reporting.mts';

type Suite = 'rn-text' | 'library';
type Snapshot = readonly [nativeHeapBytes: number, platformBytes: number];
type Sample = { baseline: Snapshot; retained: Snapshot; released: Snapshot };
type MemoryResult = {
  scenario: string;
  implementation: string;
  run: number;
  pid: number;
  device: string;
  samples: Sample[];
  prepared: boolean;
};

function counters(platform: Platform) {
  return [
    { key: 'nativeHeapBytes', label: 'Native heap', index: 0 },
    {
      key: platform === 'ios' ? 'footprintBytes' : 'managedHeapBytes',
      label: platform === 'ios' ? 'Process footprint' : 'Managed heap',
      index: 1,
    },
  ] as const;
}

function scenarios(suite: Suite) {
  return suite === 'rn-text'
    ? [
        { key: 'laid_out_chat', label: '128 laid-out paragraphs', units: 128 },
        { key: 'mounted_chat', label: '128 drawn views and their paragraphs', units: 128 },
      ]
    : [
        { key: 'prepared_chat', label: '128 prepared and laid-out texts', units: 128 },
        { key: 'glyph_fields', label: '64 independent 80 × 24 glyph fields', units: 64 },
      ];
}

function assertRecord(value: unknown): asserts value is Record<string, unknown> {
  assert(value !== null && typeof value === 'object' && !Array.isArray(value), 'Expected a memory record');
}

function bytes(value: unknown): number {
  assert(typeof value === 'number' && Number.isSafeInteger(value) && value > 0, 'Invalid memory counter');
  return value;
}

export function parseMemoryRun(
  log: string,
  run: number,
  suite: Suite,
  platform: Platform,
  implementation: string,
  prepared: boolean
): MemoryResult[] {
  assertRunSucceeded(log, run, platform);
  const definitions = scenarios(suite);
  const metrics = counters(platform);
  const records = log.split(/\r?\n/).flatMap(line => {
    const marker = 'RNTEXT_MEMORY_RESULT ';
    const index = line.indexOf(marker);
    if (index < 0) return [];
    const record: unknown = JSON.parse(line.slice(index + marker.length));
    assertRecord(record);
    return [record];
  });
  assert.equal(records.length, definitions.length, 'Incomplete memory run');
  assert.equal(new Set(records.map(record => record.scenario)).size, definitions.length, 'Duplicate memory scenario');
  return records.map(record => {
    assert.equal(record.suite, suite);
    assert.equal(record.platform, platform);
    assert.equal(record.implementation, implementation);
    assert.equal(record.run, run);
    assert.equal(record.configuration, 'Release');
    assert.equal(record.warmups, 2);
    if (platform === 'android') assert.equal(record.prepared, prepared);
    const definition = definitions.find(scenario => scenario.key === record.scenario);
    assert(definition, 'Unknown memory scenario');
    assert.equal(record.units, definition.units, 'Incorrect retained object count');
    const pid = bytes(record.pid);
    assert(typeof record.deviceName === 'string' && record.deviceName.length > 0);
    assert(typeof record.osVersion === 'string' && record.osVersion.length > 0);
    if (platform === 'android') {
      bytes(record.apiLevel);
      assert(typeof record.abi === 'string' && record.abi.length > 0);
      assert(typeof record.density === 'number' && record.density > 0 && Number.isFinite(record.density));
    } else {
      assert(typeof record.simulator === 'boolean');
      assert(typeof record.scale === 'number' && Number.isFinite(record.scale) && record.scale > 0);
    }
    const device =
      platform === 'ios'
        ? `${record.deviceName}${record.simulator ? ' simulator' : ''}, iOS ${record.osVersion} (scale ${record.scale})`
        : `${record.deviceName}, Android ${record.osVersion} (API ${record.apiLevel}, ${record.abi}, density ${record.density})`;
    assert(Array.isArray(record.samples) && record.samples.length === 5, 'Expected five memory samples');
    const snapshot = (value: unknown): Snapshot => {
      assertRecord(value);
      const data = value;
      assert.deepEqual(Object.keys(data).sort(), metrics.map(metric => metric.key).sort(), 'Incorrect memory counters');
      return [bytes(data[metrics[0].key]), bytes(data[metrics[1].key])];
    };
    const samples = record.samples.map((value: unknown): Sample => {
      assertRecord(value);
      const sample = value;
      return { baseline: snapshot(sample.baseline), retained: snapshot(sample.retained), released: snapshot(sample.released) };
    });
    return { scenario: definition.key, implementation, run, pid, device, samples, prepared };
  });
}

export function renderMemoryResults(metadata: Record<string, unknown>, directory: string, suite: Suite): string {
  const platform = metadata.platform;
  assert(platform === 'ios' || platform === 'android');
  const implementations: [string, string][] =
    suite === 'library'
      ? [['engine', 'Text Engine']]
      : [
          ['rn', 'RN Text'],
          ['textview', 'TextView'],
          ['preparedtextview', 'PreparedTextView'],
        ];
  const configurations = suite === 'rn-text' && platform === 'android' ? [false, true] : [false];
  const records: MemoryResult[] = [];
  const pids = new Set<number>();
  for (const prepared of configurations) {
    for (const [key, implementation] of implementations) {
      for (const run of [1, 2, 3]) {
        const name =
          suite === 'library'
            ? `memory-${run}.log`
            : platform === 'android'
              ? `memory-${run}-${prepared ? 'prepared' : 'default'}-${key}.log`
              : `memory-${run}-${key}.log`;
        const parsed = parseMemoryRun(readFileSync(join(directory, name), 'utf8'), run, suite, platform, implementation, prepared);
        const first = parsed[0];
        assert(first);
        assert(
          parsed.every(record => record.pid === first.pid),
          'One memory run used multiple processes'
        );
        assert(!pids.has(first.pid), 'Memory runs must use fresh processes');
        pids.add(first.pid);
        records.push(...parsed);
      }
    }
  }
  assert.equal(new Set(records.map(record => record.device)).size, 1, 'Memory device changed between runs');
  const metrics = counters(platform);
  const names = implementations.map(([, name]) => name);
  const lines = [
    '### Memory',
    '',
    `${metadata.startedAt}. ${records[0]?.device}. Release build; React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}.`,
    '',
    'Changes from each pass’s baseline, in KiB: median of three process medians ± median absolute deviation. Each process records five passes after two warm-ups. “Released” is the change remaining after dropping the workload and collecting/draining it; it includes allocator and platform caches and is not a leak measurement.',
    '',
  ];
  for (const prepared of configurations) {
    if (platform === 'android' && suite === 'rn-text') lines.push(`#### RN ${prepared ? 'prepared' : 'default'} layout`, '');
    lines.push(`| Workload | Counter | State | ${names.join(' | ')} |`, `| --- | --- | --- | ${names.map(() => '---:').join(' | ')} |`);
    for (const scenario of scenarios(suite)) {
      for (const metric of metrics) {
        for (const state of ['retained', 'released'] as const) {
          const values = names.map(implementation => {
            const processMedians = records
              .filter(
                record => record.scenario === scenario.key && record.implementation === implementation && record.prepared === prepared
              )
              .map(record => median(record.samples.map(sample => sample[state][metric.index] - sample.baseline[metric.index])));
            assert.equal(processMedians.length, 3);
            const center = median(processMedians);
            const mad = median(processMedians.map(value => Math.abs(value - center)));
            return `${(center / 1024).toFixed(1)} ± ${(mad / 1024).toFixed(1)}`;
          });
          lines.push(`| ${scenario.label} | ${metric.label} | ${state === 'retained' ? 'Held' : 'Released'} | ${values.join(' | ')} |`);
        }
      }
    }
    lines.push('');
  }
  lines.push(
    platform === 'ios'
      ? 'Native heap counts malloc allocations in use. Process footprint also reflects non-heap costs such as drawing backing stores; the counters overlap and must not be added.'
      : 'Managed heap is sampled after explicit garbage collection, with collection progress checked. Native heap uses the allocator’s allocated-byte counter.' +
          (suite === 'rn-text'
            ? ' The common software canvas is allocated before the baseline; this benchmark does not create per-view GPU surfaces.'
            : ''),
    '',
    '<details>',
    '<summary>Memory snapshots (bytes)</summary>',
    '',
    ...(suite === 'rn-text' ? [`- Git HEAD: \`${metadata.revision}\``, `- Source checksum (SHA256): \`${metadata.sourceHash}\``, ''] : []),
    '| Workload | Implementation | RN configuration | Run | Counter | Baseline | Held | Released |',
    '| --- | --- | --- | ---: | --- | --- | --- | --- |'
  );
  for (const record of records) {
    for (const metric of metrics) {
      lines.push(
        `| ${record.scenario} | ${record.implementation} | ${suite === 'rn-text' && platform === 'android' ? (record.prepared ? 'Prepared' : 'Default') : '—'} | ${record.run} | ${metric.label} | ${(['baseline', 'retained', 'released'] as const).map(state => record.samples.map(sample => sample[state][metric.index]).join(', ')).join(' | ')} |`
      );
    }
  }
  lines.push('', '</details>');
  return lines.join('\n');
}

export function updateMemoryResults(path: string, memory: string, platform: Platform) {
  const original = readFileSync(path, 'utf8');
  const heading = `## ${platform === 'ios' ? 'iOS' : 'Android'}`;
  const section = original.split(/(?=^## )/m).find(part => part.startsWith(heading + '\n'));
  assert(section, 'Missing platform results section');
  const withoutMemory = section.replace(/\n### Memory\n[\s\S]*$/, '').trimEnd();
  updateResults(path, `${withoutMemory}\n\n${memory}`, platform);
}
