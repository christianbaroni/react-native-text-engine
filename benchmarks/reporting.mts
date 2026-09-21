import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, renameSync } from 'node:fs';

export type Platform = 'ios' | 'android';

export function assertRunSucceeded(log: string, run: number, platform: Platform) {
  if (platform === 'android') {
    assert.match(log, /^OK \(1 test\)\s*$/m, `Android run ${run} did not pass`);
    const completion = [...log.matchAll(/^INSTRUMENTATION_CODE: (-?\d+)\s*$/gm)];
    assert.equal(completion.length, 1, 'Expected one instrumentation completion');
    assert.equal(completion[0]?.[1], '-1', 'Instrumentation did not finish successfully');
    assert.doesNotMatch(log, /^INSTRUMENTATION_STATUS_CODE: -\d+\s*$/m, 'Instrumentation reported a failed or skipped test');
    assert.doesNotMatch(log, /FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED/);
  } else {
    assert.match(log, /^\*\* TEST(?: EXECUTE)? SUCCEEDED \*\*\s*$/m, `Run ${run} did not complete successfully`);
    assert.doesNotMatch(log, /^\*\* TEST(?: EXECUTE)? FAILED \*\*\s*$/m, `Run ${run} includes a failed test invocation`);
  }
}

export const median = (values: number[]): number => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  const upper = sorted[middle];
  assert(upper !== undefined, 'Cannot summarize empty samples');
  return sorted.length % 2 ? upper : ((sorted[middle - 1] ?? upper) + upper) / 2;
};

export function updateResults(path: string, section: string, platform: Platform = 'ios') {
  assert(['ios', 'android'].includes(platform), 'Unknown benchmark platform');
  const heading = `## ${platform === 'android' ? 'Android' : 'iOS'}`;
  assert(section.startsWith(heading + '\n'), 'Report does not match the target platform');
  const original = readFileSync(path, 'utf8');
  const headings = [...original.matchAll(/^## .+$/gm)];
  assert.equal(headings.filter(match => match[0] === heading).length, 1, `Expected one ${heading} section`);
  const index = headings.findIndex(match => match[0] === heading);
  const first = headings[index]?.index;
  assert(first !== undefined);
  const last = headings[index + 1]?.index ?? original.length;
  const suffix = original.slice(last);
  const next = original.slice(0, first) + section.trimEnd() + (suffix ? '\n\n' + suffix : '\n');
  const temporary = `${path}.tmp`;
  writeFileSync(temporary, next);
  renameSync(temporary, path);
}
