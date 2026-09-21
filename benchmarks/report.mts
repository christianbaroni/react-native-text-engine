import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertRunSucceeded, median, updateResults, type Platform } from './reporting.mts';
import { renderMemoryResults, updateMemoryResults } from './memory-report.mts';

const implementations = ['RN Text', 'TextView', 'PreparedTextView'] as const;
type Implementation = (typeof implementations)[number];
type Scenario = {
  label: string;
  operations: number;
  androidOperations?: number;
};
type ScenarioGroup = {
  label: string;
  implementations: readonly Implementation[];
  scenarios: [string, Scenario][];
};

type RunMetadata = {
  run: number;
  pid: number;
  deviceName: string;
  osVersion: string;
} & (
  | { platform: 'ios'; sdk: string }
  | {
      platform: 'android';
      implementation: Implementation;
      enablePreparedTextLayout: boolean;
      apiLevel: number;
      density: number;
      abi: string;
    }
);
type Measurement = {
  scenario: string;
  implementation: Implementation;
  operations: number;
  samplesMs: number[];
};

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scenarioGroups: ScenarioGroup[] = [
  {
    label: 'Component lifecycle',
    implementations,
    scenarios: [
      ['fabric_chat_shadow_tree_layout', { label: 'Chat list layout', operations: 512 }],
      ['fabric_mount_and_first_draw', { label: 'Native layout, mount, and first draw', operations: 512 }],
    ],
  },
  {
    label: 'Measurement',
    implementations: ['RN Text', 'TextView'],
    scenarios: [
      ['retained_paragraph_measurement', { label: 'Retained paragraph measurement', operations: 16384 }],
      ['cold_short_label_layout', { label: 'Short labels, natural line height', operations: 512 }],
      ['cold_uniform_chat_layout', { label: 'Plain text creation and layout', operations: 512 }],
      ['cached_uniform_layout_queries_200_keys', { label: 'Manager queries, 200 keys', operations: 25600, androidOperations: 1600 }],
      [
        'cached_truncated_layout_queries_200_keys',
        { label: 'Manager queries, 200 keys, two-line limit', operations: 25600, androidOperations: 1600 },
      ],
      ['cached_uniform_layout_queries', { label: 'Manager queries, 768 keys', operations: 98304, androidOperations: 6144 }],
      [
        'cached_truncated_layout_queries',
        {
          label: 'Manager queries, 768 keys, two-line limit',
          operations: 98304,
          androidOperations: 6144,
        },
      ],
      ['cold_rich_inline_layout', { label: 'Styled text creation and layout', operations: 384 }],
    ],
  },
];
const scenarios = new Map(
  scenarioGroups.flatMap(group =>
    group.scenarios.map(([name, definition]) => [name, { ...definition, implementations: group.implementations }])
  )
);

export function parseRun(log: string, run: number, platform: Platform = 'ios') {
  assert(['ios', 'android'].includes(platform), 'Unknown benchmark platform');
  assertRunSucceeded(log, run, platform);
  const records: Record<string, unknown>[] = [];
  const metadata: Record<string, unknown>[] = [];
  for (const line of log.split(/\r?\n/)) {
    const targets: [string, Record<string, unknown>[]][] = [
      ['RNTEXT_BENCHMARK_META ', metadata],
      ['RNTEXT_BENCHMARK_RESULT ', records],
    ];
    for (const [prefix, target] of targets) {
      const index = line.indexOf(prefix);
      if (index >= 0) target.push(parseObject(line.slice(index + prefix.length)));
    }
  }
  assert.equal(metadata.length, 1, `Run ${run} must have one metadata record`);
  const meta = metadata[0];
  assert(meta);
  assert.equal(meta.run, run);
  assert.equal(meta.configuration, 'Release');
  assert.equal(meta.host, 'native-only');
  assert.equal(meta.geometryValidated, true);
  assert.equal(meta.warmups, platform === 'android' ? 10 : 2);
  assert.equal(meta.samples, 9);
  assert(typeof meta.pid === 'number' && Number.isInteger(meta.pid) && meta.pid > 0, 'Missing test process identity');
  assert(typeof meta.deviceName === 'string' && meta.deviceName.trim().length > 0 && meta.deviceName !== 'unknown');
  assert(typeof meta.osVersion === 'string' && meta.osVersion.trim().length > 0 && meta.osVersion !== 'unknown');
  const common = { run, pid: meta.pid, deviceName: meta.deviceName, osVersion: meta.osVersion };
  let runMetadata: RunMetadata;
  if (platform === 'ios') {
    assert.equal(meta.includesAutoreleasePoolDrain, true);
    assert(typeof meta.sdk === 'string');
    assert.match(meta.sdk, /^(iphoneos|iphonesimulator)\d+(\.\d+)*$/, 'Missing iOS build SDK');
    runMetadata = { ...common, platform, sdk: meta.sdk };
  } else {
    assert.equal(meta.platform, 'android');
    assertImplementation(meta.implementation);
    assert(typeof meta.enablePreparedTextLayout === 'boolean');
    assert.equal(meta.disableTextLayoutManagerCacheAndroid, false);
    assert.equal(meta.preparedTextCacheSize, 200);
    assert(typeof meta.apiLevel === 'number' && Number.isInteger(meta.apiLevel) && meta.apiLevel > 0);
    assert(typeof meta.density === 'number' && Number.isFinite(meta.density) && meta.density > 0);
    assert(typeof meta.abi === 'string' && meta.abi.length > 0);
    runMetadata = {
      ...common,
      platform,
      implementation: meta.implementation,
      enablePreparedTextLayout: meta.enablePreparedTextLayout,
      apiLevel: meta.apiLevel,
      density: meta.density,
      abi: meta.abi,
    };
  }
  const expectedCount = [...scenarios.values()].reduce(
    (count, scenario) =>
      count +
      (runMetadata.platform === 'android'
        ? Number(scenario.implementations.includes(runMetadata.implementation))
        : scenario.implementations.length),
    0
  );
  assert.equal(records.length, expectedCount, 'Incomplete comparison');
  const seen = new Set<string>();
  const measurements: Measurement[] = [];
  for (const record of records) {
    assert(typeof record.scenario === 'string');
    const scenario = scenarios.get(record.scenario);
    assert(scenario, `Unknown scenario: ${record.scenario}`);
    assertImplementation(record.implementation);
    if (platform === 'android') assert.equal(record.implementation, meta.implementation, 'Mixed implementations in one process');
    const key = `${record.scenario}/${record.implementation}`;
    assert(!seen.has(key), `Duplicate result: ${key}`);
    seen.add(key);
    assert(scenario.implementations.includes(record.implementation), `Unsupported comparison: ${key}`);
    const operations = platform === 'android' ? (scenario.androidOperations ?? scenario.operations) : scenario.operations;
    assert.equal(record.operations, operations, `Incorrect operation count: ${key}`);
    assert(Array.isArray(record.samplesMs) && record.samplesMs.length === 9, `Incomplete samples: ${key}`);
    const samples: unknown[] = record.samplesMs;
    assert(
      samples.every((value): value is number => typeof value === 'number' && Number.isFinite(value) && value > 0),
      `Invalid duration: ${key}`
    );
    measurements.push({ scenario: record.scenario, implementation: record.implementation, operations, samplesMs: samples });
  }
  return { ...runMetadata, records: measurements };
}

export function renderComparison(metadata: Record<string, unknown>, logs: string[]) {
  const platform = metadata.platform ?? 'ios';
  assertPlatform(platform);
  assert.equal(logs.length, platform === 'android' ? 18 : 3, 'Three fresh processes per implementation and configuration are required');
  const runs = logs.map((log, index) => parseRun(log, (index % 3) + 1, platform));
  assert.equal(new Set(runs.map(run => run.pid)).size, runs.length, 'Each run must use a fresh process');
  assert.equal(new Set(runs.map(run => `${run.deviceName}/${run.osVersion}`)).size, 1, 'Runs used different devices');
  if (platform === 'android') {
    const androidRuns = runs.filter(run => run.platform === 'android');
    assert.equal(new Set(androidRuns.map(run => `${run.apiLevel}/${run.abi}/${run.density}`)).size, 1, 'Android configuration changed');
    for (const prepared of [false, true]) {
      for (const implementation of implementations) {
        assert.deepEqual(
          androidRuns.filter(run => run.enablePreparedTextLayout === prepared && run.implementation === implementation).map(run => run.run),
          [1, 2, 3],
          'Each Android implementation and configuration requires runs 1, 2, and 3'
        );
      }
    }
    assert.equal(metadata.compilation, 'speed');
    assert(typeof metadata.apkSha256 === 'string');
    assert.match(metadata.apkSha256, /^[a-f0-9]{64}$/);
  } else {
    const iosRuns = runs.filter(run => run.platform === 'ios');
    assert.equal(new Set(iosRuns.map(run => run.sdk)).size, 1, 'iOS build SDK changed');
    assert(typeof metadata.xcode === 'string');
  }
  assert(typeof metadata.startedAt === 'string');
  const first = runs[0];
  assert(first);
  const date = new Date(metadata.startedAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
  const lines = [
    `## ${platform === 'android' ? 'Android' : 'iOS'}`,
    '',
    first.platform === 'android'
      ? `${date}. ${first.deviceName}, Android ${first.osVersion} (API ${first.apiLevel}). React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}, Release build.`
      : `${date}. ${first.deviceName}${first.sdk.startsWith('iphonesimulator') ? ' simulator' : ''}, iOS ${first.osVersion}. React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}, Release build.`,
    '',
  ];
  const configurations = platform === 'android' ? [false, true] : [false];
  for (const prepared of configurations) {
    const group = runs.filter(run => run.platform === 'ios' || run.enablePreparedTextLayout === prepared);
    if (platform === 'android') lines.push(`### RN Text${prepared ? ' with prepared layout' : ' with default layout'}`, '');
    for (const scenarioGroup of scenarioGroups) {
      const names = scenarioGroup.implementations;
      lines.push(
        `${platform === 'android' ? '####' : '###'} ${scenarioGroup.label}`,
        '',
        `| Test | Operations/sample | ${names.map(name => `${name} (ms)`).join(' | ')} | ${names
          .slice(1)
          .map(name => `${name} / RN`)
          .join(' | ')} |`,
        `| --- | ${Array(names.length * 2)
          .fill('---:')
          .join(' | ')} |`
      );
      for (const [scenario, definition] of scenarioGroup.scenarios) {
        const operations = platform === 'android' ? (definition.androidOperations ?? definition.operations) : definition.operations;
        const stats = names.map(implementation => {
          const implementationRuns = group.filter(run => run.platform === 'ios' || run.implementation === implementation);
          const values = implementationRuns.map(run => {
            const record = run.records.find(record => record.scenario === scenario && record.implementation === implementation);
            assert(record, `Missing ${scenario}/${implementation}`);
            return median(record.samplesMs);
          });
          const value = median(values);
          return { median: value, mad: median(values.map(sample => Math.abs(sample - value))) };
        });
        const baseline = stats[0];
        assert(baseline);
        lines.push(
          `| ${definition.label} | ${operations.toLocaleString('en-US')} | ${stats.map(stat => `${stat.median.toFixed(3)} ± ${stat.mad.toFixed(3)}`).join(' | ')} | ${stats
            .slice(1)
            .map(stat => `${(stat.median / baseline.median).toFixed(3)}×`)
            .join(' | ')} |`
        );
      }
      lines.push('');
    }
    if (platform === 'android' && prepared) {
      lines.push(
        'The 200-key manager-query rows hit RN’s prepared-layout cache after warm-up; the 768-key rows miss on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.',
        ''
      );
    }
  }
  lines.push(
    '<details>',
    '<summary>Run details and samples</summary>',
    '',
    `- Started: ${metadata.startedAt}`,
    `- Host: ${metadata.cpu}, ${metadata.hostOS ?? `macOS ${metadata.macos}`}, ${metadata.architecture}`,
    ...(first.platform === 'android'
      ? [
          `- Device: ${first.abi}, density ${first.density}; ART compilation: ${metadata.compilation}`,
          '- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Repeated-query workloads visit either 200 or 768 text/width combinations.',
          `- Toolchain: ${metadata.java}; Gradle ${metadata.gradle}; Node ${metadata.node}`,
          `- APK SHA256: \`${metadata.apkSha256}\``,
        ]
      : [`- Toolchain: ${String(metadata.xcode).replaceAll('\n', ' / ')}; SDK ${first.sdk}; Node ${metadata.node}`]),
    `- Git HEAD: \`${metadata.revision}\``,
    `- Source checksum (SHA256): \`${metadata.sourceHash}\``,
    '',
    'Each row lists nine samples from one app process, in measurement order. All samples are included.',
    '',
    `| Test | Implementation | ${platform === 'android' ? 'RN configuration | ' : ''}Run | Samples (ms) |`,
    `| --- | --- | ${platform === 'android' ? '--- | ' : ''}---: | --- |`
  );
  for (const [scenario, definition] of scenarios) {
    const label = definition.label;
    for (const implementation of implementations) {
      runs.forEach(run => {
        const record = run.records.find(item => item.scenario === scenario && item.implementation === implementation);
        if (!record) return;
        const configuration =
          platform === 'android' ? `${run.platform === 'android' && run.enablePreparedTextLayout ? 'Prepared' : 'Default'} | ` : '';
        lines.push(
          `| ${label} | ${implementation} | ${configuration}${run.run} | ${record.samplesMs.map(value => value.toFixed(6)).join(', ')} |`
        );
      });
    }
  }
  lines.push('', '</details>');
  return lines.join('\n');
}

function sourceIdentity(platform: Platform) {
  const platformPaths =
    platform === 'android'
      ? [
          'android/build.gradle',
          'android/src/main',
          'android/src/fabric',
          'android/src/androidTest',
          'android/src/nativeTest',
          'examples/android/build.gradle',
          'examples/android/settings.gradle',
          'examples/android/gradle.properties',
          'examples/android/gradle/wrapper/gradle-wrapper.properties',
        ]
      : [
          'ios',
          'RNTextEngine.podspec',
          'examples/ios/Podfile.lock',
          'examples/ios/example/AppDelegate.swift',
          'examples/ios/example.xcodeproj/project.pbxproj',
          'examples/ios/exampleTests',
        ];
  const tracked = execFileSync(
    'git',
    [
      'ls-files',
      '-z',
      '--cached',
      '--others',
      '--exclude-standard',
      '--',
      ...platformPaths,
      'common',
      'src',
      'package.json',
      'examples/package.json',
      'examples/yarn.lock',
    ],
    { cwd: root, encoding: 'utf8' }
  )
    .split('\0')
    .filter(Boolean);
  const paths = new Set([
    ...tracked,
    ...readdirSync(join(root, 'benchmarks'))
      .filter(name => /\.(mts|sh)$/.test(name))
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
  const [command, directory, option] = process.argv.slice(2);
  assert(
    directory && command && ['capture', 'artifact', 'write', 'memory'].includes(command),
    'Usage: node --import jiti/register benchmarks/report.mts <capture|artifact|write|memory> <run-directory> [platform|apk]'
  );
  const runDirectory = resolve(directory);
  const metadataPath = join(runDirectory, 'metadata.json');
  if (command === 'capture') {
    const platform = option ?? 'ios';
    assertPlatform(platform);
    const read = (command: string, args: string[]) => execFileSync(command, args, { encoding: 'utf8' }).trim();
    const metadata = {
      ...sourceIdentity(platform),
      platform,
      startedAt: new Date().toISOString(),
      relativeRunDirectory: relative(join(root, 'benchmarks'), runDirectory),
      reactNativeVersion: parseObject(readFileSync(join(root, 'examples/node_modules/react-native/package.json'), 'utf8')).version,
      textEngineVersion: parseObject(readFileSync(join(root, 'package.json'), 'utf8')).version,
      hostOS: os.type() + ' ' + os.release(),
      ...(platform === 'android'
        ? {
            java: read(process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin/java') : 'java', ['--version']).split('\n')[0],
            gradle: readFileSync(join(root, 'examples/android/gradle/wrapper/gradle-wrapper.properties'), 'utf8').match(
              /gradle-([\d.]+)-/
            )?.[1],
            compilation: 'speed',
          }
        : {
            xcode: read('xcodebuild', ['-version']),
          }),
      cpu: os.cpus()[0]?.model,
      architecture: os.arch(),
      node: process.version,
    };
    writeFileSync(metadataPath, JSON.stringify(metadata, null, 2) + '\n');
  } else {
    const metadata = parseObject(readFileSync(metadataPath, 'utf8'));
    const platform = metadata.platform ?? 'ios';
    assertPlatform(platform);
    const current = sourceIdentity(platform);
    assert.equal(current.revision, metadata.revision, 'Git revision changed during the benchmark');
    assert.equal(current.sourceHash, metadata.sourceHash, 'Benchmark inputs changed during the run');
    if (command === 'artifact') {
      assert.equal(platform, 'android');
      assert(option, 'Provide the benchmark APK path');
      copyFileSync(resolve(option), join(runDirectory, 'benchmark.apk'));
      metadata.apkSha256 = createHash('sha256')
        .update(readFileSync(join(runDirectory, 'benchmark.apk')))
        .digest('hex');
      writeFileSync(metadataPath, JSON.stringify(metadata, null, 2) + '\n');
      return;
    }
    if (platform === 'android') {
      assert.match(
        readFileSync(join(runDirectory, 'compilation.log'), 'utf8'),
        /^Success\s*$/m,
        'Android ahead-of-time compilation did not succeed'
      );
      assert.equal(
        createHash('sha256')
          .update(readFileSync(join(runDirectory, 'benchmark.apk')))
          .digest('hex'),
        metadata.apkSha256,
        'Benchmark APK changed during the run'
      );
    }
    if (command === 'memory') {
      assert(option === 'library' || option === 'rn-text', 'Choose library or rn-text');
      const section = renderMemoryResults(metadata, runDirectory, option);
      updateMemoryResults(join(root, `benchmarks/${option}/results.md`), section, platform);
      return;
    }
    const names =
      platform === 'android'
        ? ['default', 'prepared'].flatMap(mode =>
            ['rn', 'textview', 'preparedtextview'].flatMap(implementation =>
              [1, 2, 3].map(run => `run-${run}-${mode}-${implementation}.log`)
            )
          )
        : [1, 2, 3].map(run => `run-${run}.log`);
    const logs = names.map(name => readFileSync(join(runDirectory, name), 'utf8'));
    const section = renderComparison(metadata, logs) + '\n\n' + renderMemoryResults(metadata, runDirectory, 'rn-text');
    updateResults(join(root, 'benchmarks/rn-text/results.md'), section, platform);
    console.log('Updated benchmarks/rn-text/results.md.');
  }
}

function parseObject(json: string): Record<string, unknown> {
  const value: unknown = JSON.parse(json);
  assert(isRecord(value), 'Expected a JSON object');
  return value;
}

function assertPlatform(value: unknown): asserts value is Platform {
  assert(value === 'ios' || value === 'android', 'Unknown benchmark platform');
}

function assertImplementation(value: unknown): asserts value is Implementation {
  assert(
    implementations.some(implementation => implementation === value),
    'Unknown implementation'
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}
