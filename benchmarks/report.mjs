import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, readFileSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scenarios = new Map([
  ['fabric_chat_shadow_tree_layout', { label: 'Chat list layout', operations: 512 }],
  ['fabric_mount_and_first_draw', { label: 'Native layout, mount, and first draw', operations: 512 }],
  ['retained_paragraph_measurement', { label: 'Retained paragraph measurement', operations: 16384 }],
  ['cold_short_label_layout', { label: 'Short labels, natural line height', operations: 512 }],
  ['cold_uniform_chat_layout', { label: 'Plain text creation and layout', operations: 512 }],
  [
    'cached_uniform_layout_queries',
    { label: 'Manager queries, 768 keys', operations: 98304, androidOperations: 6144 },
  ],
  [
    'cached_truncated_layout_queries',
    {
      label: 'Manager queries, 768 keys, two-line limit',
      operations: 98304,
      androidOperations: 6144,
    },
  ],
  ['cold_rich_inline_layout', { label: 'Styled text creation and layout', operations: 384 }],
]);
const implementations = ['RN Text', 'TextView'];

export function parseRun(log, run, platform = 'ios') {
  assert(['ios', 'android'].includes(platform), 'Unknown benchmark platform');
  if (platform === 'android') {
    assert.match(log, /^OK \(1 test\)\s*$/m, `Android run ${run} did not pass`);
    const completion = [...log.matchAll(/^INSTRUMENTATION_CODE: (-?\d+)\s*$/gm)];
    assert.equal(completion.length, 1, 'Expected one instrumentation completion');
    assert.equal(completion[0][1], '-1', 'Instrumentation did not finish successfully');
    assert.doesNotMatch(log, /^INSTRUMENTATION_STATUS_CODE: -\d+\s*$/m, 'Instrumentation reported a failed or skipped test');
    assert.doesNotMatch(log, /FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED/);
  } else {
    assert.match(log, /^\*\* TEST(?: EXECUTE)? SUCCEEDED \*\*\s*$/m, `Run ${run} did not complete successfully`);
    assert.doesNotMatch(log, /^\*\* TEST(?: EXECUTE)? FAILED \*\*\s*$/m, `Run ${run} includes a failed test invocation`);
  }
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
  assert.equal(meta.warmups, platform === 'android' ? 10 : 2);
  assert.equal(meta.samples, 9);
  if (platform === 'ios') {
    assert.equal(meta.includesAutoreleasePoolDrain, true);
    assert.match(meta.sdk, /^(iphoneos|iphonesimulator)\d+(\.\d+)*$/, 'Missing iOS build SDK');
  } else {
    assert.equal(meta.platform, 'android');
    assert(implementations.includes(meta.implementation), 'Missing isolated implementation');
    assert.equal(typeof meta.enablePreparedTextLayout, 'boolean');
    assert.equal(meta.disableTextLayoutManagerCacheAndroid, false);
    assert.equal(meta.preparedTextCacheSize, 200);
    assert(Number.isInteger(meta.apiLevel) && meta.apiLevel > 0);
    assert(Number.isFinite(meta.density) && meta.density > 0);
    assert(typeof meta.abi === 'string' && meta.abi.length > 0);
  }
  assert(Number.isInteger(meta.pid) && meta.pid > 0, 'Missing test process identity');
  assert(typeof meta.deviceName === 'string' && meta.deviceName.trim().length > 0 && meta.deviceName !== 'unknown');
  assert(typeof meta.osVersion === 'string' && meta.osVersion.trim().length > 0 && meta.osVersion !== 'unknown');
  assert.equal(records.length, scenarios.size * (platform === 'android' ? 1 : implementations.length), 'Incomplete comparison');
  const seen = new Set();
  for (const record of records) {
    assert(scenarios.has(record.scenario), `Unknown scenario: ${record.scenario}`);
    assert(implementations.includes(record.implementation), 'Unknown implementation');
    if (platform === 'android') assert.equal(record.implementation, meta.implementation, 'Mixed implementations in one process');
    const key = `${record.scenario}/${record.implementation}`;
    assert(!seen.has(key), `Duplicate result: ${key}`);
    seen.add(key);
    const scenario = scenarios.get(record.scenario);
    const operations = platform === 'android' ? (scenario.androidOperations ?? scenario.operations) : scenario.operations;
    assert.equal(record.operations, operations, `Incorrect operation count: ${key}`);
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
  const platform = metadata.platform ?? 'ios';
  assert.equal(logs.length, platform === 'android' ? 12 : 3, 'Three fresh processes per implementation and configuration are required');
  const runs = logs.map((log, index) => parseRun(log, (index % 3) + 1, platform));
  assert.equal(new Set(runs.map(run => run.meta.pid)).size, runs.length, 'Each run must use a fresh process');
  assert.equal(new Set(runs.map(run => `${run.meta.deviceName}/${run.meta.osVersion}`)).size, 1, 'Runs used different devices');
  if (platform === 'android') {
    assert.equal(
      new Set(runs.map(run => `${run.meta.apiLevel}/${run.meta.abi}/${run.meta.density}`)).size,
      1,
      'Android configuration changed'
    );
    for (const prepared of [false, true]) {
      for (const implementation of implementations) {
        assert.deepEqual(
          runs.filter(run => run.meta.enablePreparedTextLayout === prepared && run.meta.implementation === implementation).map(run => run.meta.run),
          [1, 2, 3],
          'Each Android implementation and configuration requires runs 1, 2, and 3'
        );
      }
    }
    assert.equal(metadata.compilation, 'speed');
    assert.match(metadata.apkSha256, /^[a-f0-9]{64}$/);
  } else {
    assert.equal(new Set(runs.map(run => run.meta.sdk)).size, 1, 'iOS build SDK changed');
  }
  const date = new Date(metadata.startedAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
  const lines = [
    `## ${platform === 'android' ? 'Android' : 'iOS'}`,
    '',
    platform === 'android'
      ? `${date}. ${runs[0].meta.deviceName}, Android ${runs[0].meta.osVersion} (API ${runs[0].meta.apiLevel}). React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}, Release build.`
      : `${date}. ${runs[0].meta.deviceName}${runs[0].meta.sdk.startsWith('iphonesimulator') ? ' simulator' : ''}, iOS ${runs[0].meta.osVersion}. React Native ${metadata.reactNativeVersion}, Text Engine ${metadata.textEngineVersion}, Release build.`,
    '',
  ];
  const configurations = platform === 'android' ? [false, true] : [false];
  for (const prepared of configurations) {
    const group = platform === 'android' ? runs.filter(run => run.meta.enablePreparedTextLayout === prepared) : runs;
    if (platform === 'android') lines.push(`### RN Text${prepared ? ' with prepared layout' : ' with default layout'}`, '');
    lines.push('| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |', '| --- | ---: | ---: | ---: | ---: |');
    for (const [scenario, definition] of scenarios) {
      const label = definition.label;
      const operations = platform === 'android' ? (definition.androidOperations ?? definition.operations) : definition.operations;
      const stats = implementations.map(implementation => {
        const implementationRuns = platform === 'android' ? group.filter(run => run.meta.implementation === implementation) : group;
        const values = implementationRuns.map(run =>
          median(run.records.find(record => record.scenario === scenario && record.implementation === implementation).samplesMs)
        );
        const value = median(values);
        return { median: value, mad: median(values.map(sample => Math.abs(sample - value))) };
      });
      lines.push(
        `| ${label} | ${operations.toLocaleString('en-US')} | ${stats[0].median.toFixed(3)} ± ${stats[0].mad.toFixed(3)} | ${stats[1].median.toFixed(3)} ± ${stats[1].mad.toFixed(3)} | ${(stats[1].median / stats[0].median).toFixed(3)}× |`
      );
    }
    lines.push('');
    if (platform === 'android' && prepared) {
      lines.push('The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.', '');
    }
  }
  lines.push(
    '<details>',
    '<summary>Run details and samples</summary>',
    '',
    `- Started: ${metadata.startedAt}`,
    `- Host: ${metadata.cpu}, ${metadata.hostOS ?? `macOS ${metadata.macos}`}, ${metadata.architecture}`,
    ...(platform === 'android'
      ? [
          `- Device: ${runs[0].meta.abi}, density ${runs[0].meta.density}; ART compilation: ${metadata.compilation}`,
          '- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.',
          `- Toolchain: ${metadata.java}; Gradle ${metadata.gradle}; Node ${metadata.node}`,
          `- APK SHA256: \`${metadata.apkSha256}\``,
        ]
      : [`- Toolchain: ${metadata.xcode.replaceAll('\n', ' / ')}; SDK ${runs[0].meta.sdk}; Node ${metadata.node}`]),
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
        const configuration = platform === 'android' ? `${run.meta.enablePreparedTextLayout ? 'Prepared' : 'Default'} | ` : '';
        lines.push(
          `| ${label} | ${implementation} | ${configuration}${run.meta.run} | ${record.samplesMs.map(value => value.toFixed(6)).join(', ')} |`
        );
      });
    }
  }
  lines.push('', '</details>');
  return lines.join('\n');
}

export function updateResults(path, section, platform = 'ios') {
  assert(['ios', 'android'].includes(platform), 'Unknown benchmark platform');
  const heading = `## ${platform === 'android' ? 'Android' : 'iOS'}`;
  assert(section.startsWith(heading + '\n'), 'Report does not match the target platform');
  const original = readFileSync(path, 'utf8');
  const headings = [...original.matchAll(/^## .+$/gm)];
  assert.equal(headings.filter(match => match[0] === heading).length, 1, `Expected one ${heading} section`);
  const index = headings.findIndex(match => match[0] === heading);
  const first = headings[index].index;
  const last = headings[index + 1]?.index ?? original.length;
  const suffix = original.slice(last);
  const next = original.slice(0, first) + section.trimEnd() + (suffix ? '\n\n' + suffix : '\n');
  const temporary = `${path}.tmp`;
  writeFileSync(temporary, next);
  renameSync(temporary, path);
}

function sourceIdentity(platform) {
  const platformPaths =
    platform === 'android'
      ? [
          'android/build.gradle',
          'android/src/main',
          'android/src/fabric',
          'android/src/androidTest',
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
          'examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm',
          'examples/ios/exampleTests/RNTextEngineTextViewTestHelpers.h',
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
  const [command, directory, option] = process.argv.slice(2);
  assert(
    directory && ['capture', 'artifact', 'write'].includes(command),
    'Usage: node benchmarks/report.mjs <capture|artifact|write> <run-directory> [platform|apk]'
  );
  const runDirectory = resolve(directory);
  const metadataPath = join(runDirectory, 'metadata.json');
  if (command === 'capture') {
    const platform = option ?? 'ios';
    assert(['ios', 'android'].includes(platform), 'Unknown benchmark platform');
    const read = (command, args) => execFileSync(command, args, { encoding: 'utf8' }).trim();
    const metadata = {
      ...sourceIdentity(platform),
      platform,
      startedAt: new Date().toISOString(),
      relativeRunDirectory: relative(join(root, 'benchmarks'), runDirectory),
      reactNativeVersion: JSON.parse(readFileSync(join(root, 'examples/node_modules/react-native/package.json'), 'utf8')).version,
      textEngineVersion: JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version,
      hostOS: os.type() + ' ' + os.release(),
      ...(platform === 'android'
        ? {
            java: read(process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin/java') : 'java', ['--version']).split('\n')[0],
            gradle: readFileSync(join(root, 'examples/android/gradle/wrapper/gradle-wrapper.properties'), 'utf8').match(
              /gradle-([\d.]+)-/
            )[1],
            compilation: 'speed',
          }
        : {
            xcode: read('xcodebuild', ['-version']),
          }),
      cpu: os.cpus()[0].model,
      architecture: os.arch(),
      node: process.version,
    };
    writeFileSync(metadataPath, JSON.stringify(metadata, null, 2) + '\n');
  } else {
    const metadata = JSON.parse(readFileSync(metadataPath, 'utf8'));
    const platform = metadata.platform ?? 'ios';
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
    const names =
      platform === 'android'
        ? ['default', 'prepared'].flatMap(mode => ['rn', 'textview'].flatMap(implementation =>
            [1, 2, 3].map(run => `run-${run}-${mode}-${implementation}.log`)))
        : [1, 2, 3].map(run => `run-${run}.log`);
    const logs = names.map(name => readFileSync(join(runDirectory, name), 'utf8'));
    const section = renderComparison(metadata, logs);
    updateResults(join(root, 'benchmarks/rn-text/results.md'), section, platform);
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
