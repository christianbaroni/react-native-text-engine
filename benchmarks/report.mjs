import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const begin = '<!-- BEGIN IOS TEXT COMPARISON -->';
const end = '<!-- END IOS TEXT COMPARISON -->';
const scenarios = new Map([
  ['fabric_chat_shadow_tree_layout', { label: 'Chat list layout', operations: 512 }],
  ['cold_uniform_chat_layout', { label: 'Plain text creation and layout', operations: 512 }],
  ['cached_uniform_layout_queries', { label: 'Cached layout', operations: 98304 }],
  ['cached_truncated_layout_queries', { label: 'Cached layout, two-line limit', operations: 98304 }],
  ['cold_rich_inline_layout', { label: 'Styled text creation and layout', operations: 384 }],
]);
const implementations = ['RN Text', 'TextView'];

export function parseRun(log, run) {
  assert.match(log, /^\*\* TEST(?: EXECUTE)? SUCCEEDED \*\*\s*$/m, `Run ${run} did not complete successfully`);
  assert.doesNotMatch(log, /^\*\* TEST(?: EXECUTE)? FAILED \*\*\s*$/m, `Run ${run} includes a failed test invocation`);
  const records = [];
  const metadata = [];
  for (const line of log.split(/\r?\n/)) {
    for (const [prefix, target] of [
      ['RNTEXT_BENCHMARK_META ', metadata],
      ['RNTEXT_BENCHMARK_RESULT ', records],
    ]) {
      const index = line.indexOf(prefix);
      if (index >= 0) target.push(JSON.parse(line.slice(index + prefix.length)));
    }
  }
  assert.equal(metadata.length, 1, `Run ${run} must have one metadata record`);
  const meta = metadata[0];
  assert.equal(meta.run, run);
  assert.equal(meta.configuration, 'Release');
  assert.equal(meta.host, 'native-only');
  assert.equal(meta.geometryValidated, true);
  assert.equal(meta.warmups, 2);
  assert.equal(meta.samples, 9);
  assert.equal(meta.includesAutoreleasePoolDrain, true);
  assert(Number.isInteger(meta.pid) && meta.pid > 0, 'Missing test process identity');
  assert(typeof meta.deviceName === 'string' && meta.deviceName.trim().length > 0 && meta.deviceName !== 'unknown');
  assert(typeof meta.osVersion === 'string' && meta.osVersion.trim().length > 0 && meta.osVersion !== 'unknown');
  assert.equal(records.length, scenarios.size * implementations.length, 'Incomplete comparison');
  const seen = new Set();
  for (const record of records) {
    assert(scenarios.has(record.scenario), `Unknown scenario: ${record.scenario}`);
    assert(implementations.includes(record.implementation), 'Unknown implementation');
    const key = `${record.scenario}/${record.implementation}`;
    assert(!seen.has(key), `Duplicate result: ${key}`);
    seen.add(key);
    assert.equal(record.operations, scenarios.get(record.scenario).operations, `Incorrect operation count: ${key}`);
    assert(Array.isArray(record.samplesMs) && record.samplesMs.length === 9, `Incomplete samples: ${key}`);
    assert(
      record.samplesMs.every(value => Number.isFinite(value) && value > 0),
      `Invalid duration: ${key}`
    );
  }
  return { meta, records };
}

const median = values => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};

export function renderComparison(metadata, logs) {
  assert.equal(logs.length, 3, 'Three fresh processes are required');
  const runs = logs.map((log, index) => parseRun(log, index + 1));
  assert.equal(new Set(runs.map(run => run.meta.pid)).size, 3, 'Each run must use a fresh process');
  assert.equal(new Set(runs.map(run => `${run.meta.deviceName}/${run.meta.osVersion}`)).size, 1, 'Runs used different simulators');
  const date = new Date(metadata.startedAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
  const lines = [
    `## ${date}`,
    '',
    `${runs[0].meta.deviceName} simulator, iOS ${runs[0].meta.osVersion}. React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}, Release build.`,
    '',
    'Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.',
    '',
    '| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |',
    '| --- | ---: | ---: | ---: | ---: |',
  ];
  for (const [scenario, { label, operations }] of scenarios) {
    const stats = implementations.map(implementation => {
      const values = runs.map(run =>
        median(run.records.find(record => record.scenario === scenario && record.implementation === implementation).samplesMs)
      );
      const value = median(values);
      return { median: value, mad: median(values.map(sample => Math.abs(sample - value))) };
    });
    lines.push(
      `| ${label} | ${operations.toLocaleString('en-US')} | ${stats[0].median.toFixed(3)} ± ${stats[0].mad.toFixed(3)} | ${stats[1].median.toFixed(3)} ± ${stats[1].mad.toFixed(3)} | ${(stats[1].median / stats[0].median).toFixed(3)}× |`
    );
  }
  lines.push(
    '',
    'See the [method](README.md#method) for sample counts, timing, and layout checks.',
    '',
    '<details>',
    '<summary>Run details and samples</summary>',
    '',
    `- Started: ${metadata.startedAt}`,
    `- Host: ${metadata.cpu}, macOS ${metadata.macos}, ${metadata.architecture}`,
    `- Toolchain: ${metadata.xcode.replaceAll('\n', ' / ')}; simulator SDK ${metadata.sdk}; Node ${metadata.node}`,
    `- Git HEAD: \`${metadata.revision}\``,
    `- Source checksum (SHA256): \`${metadata.sourceHash}\``,
    `- Local logs: \`benchmarks/${metadata.relativeRunDirectory}\``,
    '',
    'Each row lists nine samples from one app process, in measurement order. All samples are included.',
    '',
    '| Test | Implementation | Run | Samples (ms) |',
    '| --- | --- | ---: | --- |'
  );
  for (const [scenario, { label }] of scenarios) {
    for (const implementation of implementations) {
      runs.forEach((run, index) => {
        const record = run.records.find(item => item.scenario === scenario && item.implementation === implementation);
        lines.push(`| ${label} | ${implementation} | ${index + 1} | ${record.samplesMs.map(value => value.toFixed(6)).join(', ')} |`);
      });
    }
  }
  lines.push('', '</details>');
  return lines.join('\n');
}

export function updateResults(path, section) {
  const original = readFileSync(path, 'utf8');
  assert.equal(original.split(begin).length, 2, 'Expected one comparison section start');
  assert.equal(original.split(end).length, 2, 'Expected one comparison section end');
  const first = original.indexOf(begin) + begin.length;
  const last = original.indexOf(end);
  assert(first < last, 'Invalid comparison section boundaries');
  const next = original.slice(0, first) + '\n\n' + section + '\n\n' + original.slice(last);
  const temporary = `${path}.tmp`;
  writeFileSync(temporary, next);
  renameSync(temporary, path);
}

function sourceIdentity() {
  const tracked = execFileSync(
    'git',
    [
      'ls-files',
      '-z',
      '--',
      'ios',
      'common',
      'src',
      'package.json',
      'RNTextEngine.podspec',
      'examples/package.json',
      'examples/yarn.lock',
      'examples/ios/Podfile.lock',
      'examples/ios/example/AppDelegate.swift',
      'examples/ios/example.xcodeproj/project.pbxproj',
    ],
    { cwd: root, encoding: 'utf8' }
  )
    .split('\0')
    .filter(Boolean);
  const paths = new Set([
    ...tracked,
    'examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm',
    ...readdirSync(join(root, 'benchmarks'))
      .filter(name => /\.(mjs|sh)$/.test(name))
      .map(name => `benchmarks/${name}`),
  ]);
  const hash = createHash('sha256');
  for (const path of [...paths].sort())
    hash
      .update(path)
      .update('\0')
      .update(readFileSync(join(root, path)))
      .update('\0');
  return {
    revision: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
    sourceHash: hash.digest('hex'),
  };
}

function main() {
  const [command, directory] = process.argv.slice(2);
  assert(directory && ['capture', 'write'].includes(command), 'Usage: node benchmarks/report.mjs <capture|write> <run-directory>');
  const runDirectory = resolve(directory);
  const metadataPath = join(runDirectory, 'metadata.json');
  if (command === 'capture') {
    const read = (command, args) => execFileSync(command, args, { encoding: 'utf8' }).trim();
    const metadata = {
      ...sourceIdentity(),
      startedAt: new Date().toISOString(),
      relativeRunDirectory: relative(join(root, 'benchmarks'), runDirectory),
      reactNativeVersion: JSON.parse(readFileSync(join(root, 'examples/node_modules/react-native/package.json'), 'utf8')).version,
      textEngineVersion: JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version,
      macos: read('sw_vers', ['-productVersion']),
      xcode: read('xcodebuild', ['-version']),
      sdk: read('xcrun', ['--sdk', 'iphonesimulator', '--show-sdk-version']),
      cpu: os.cpus()[0].model,
      architecture: os.arch(),
      node: process.version,
    };
    writeFileSync(metadataPath, JSON.stringify(metadata, null, 2) + '\n');
  } else {
    const metadata = JSON.parse(readFileSync(metadataPath, 'utf8'));
    const current = sourceIdentity();
    assert.equal(current.revision, metadata.revision, 'Git revision changed during the benchmark');
    assert.equal(current.sourceHash, metadata.sourceHash, 'Benchmark inputs changed during the run');
    const logs = [1, 2, 3].map(run => readFileSync(join(runDirectory, `run-${run}.log`), 'utf8'));
    const section = renderComparison(metadata, logs);
    updateResults(join(root, 'benchmarks/rn-text/results.md'), section);
    console.log('Updated benchmarks/rn-text/results.md.');
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
