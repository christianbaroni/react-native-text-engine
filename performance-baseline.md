# Performance Baseline

This file records the current measured baseline for the `react-native-text-engine`
performance suite.

It is the calibration point for future optimization work.

## Current Baseline

### iOS

Environment:

- Date: 2026-04-24 21:38 EDT
- Device: iPhone 17 Pro simulator
- Runtime: iOS 26.2 simulator
- Xcode: 26.3 (`17C529`)
- Build: `Release`
- Test harness: XCTest wall-clock performance metric
- Recorded samples per scenario: 10
- Warm-up policy: one untimed invocation of the measured script before each recorded sample

These numbers came from a full iOS rebaseline run of
[`IOS_CONFIGURATION=Release ./scripts/run-ios-performance-tests.sh`](/Users/christian/dev/react-native-pretext/scripts/run-ios-performance-tests.sh),
which executes the full `RNTextEnginePerformanceTests` XCTest performance suite
in two `xcodebuild test` passes.

#### Prepared Text

| Scenario | Measured block | Inner loop per block | Average | Relative stddev |
| --- | --- | ---: | ---: | ---: |
| `testPreparedBatchCreateChatLifecycle` | prepare 128 chat texts as one batch, then release handles | 2048 | 0.301 s | 1.171% |
| `testPreparedBatchLayoutReuseChat` | lay out one prepared batch of 128 chat texts | 24 | 0.002 s | 4.034% |
| `testOneShotMeasureBatchChat` | one-shot measure 128 chat texts | 2 | 0.011 s | 1.319% |
| `testPrepareInlineRunsLifecycle` | prepare one long styled block with inline runs, then release | 4096 | 0.203 s | 0.701% |

Raw samples:

```text
testPreparedBatchCreateChatLifecycle
[0.300923, 0.298907, 0.308231, 0.306022, 0.301534, 0.302614, 0.296876, 0.296805, 0.298707, 0.301106]

testPreparedBatchLayoutReuseChat
[0.001921, 0.001849, 0.001822, 0.001768, 0.001863, 0.001734, 0.001905, 0.001733, 0.001750, 0.001709]

testOneShotMeasureBatchChat
[0.010799, 0.010991, 0.010774, 0.010667, 0.010615, 0.010573, 0.010650, 0.010535, 0.010542, 0.010528]

testPrepareInlineRunsLifecycle
[0.201442, 0.202341, 0.204065, 0.204946, 0.204818, 0.201109, 0.201278, 0.203863, 0.204378, 0.202680]
```

#### Glyph Field and Variable Flow

| Scenario | Measured block | Inner loop per block | Average | Relative stddev |
| --- | --- | ---: | ---: | ---: |
| `testGlyphBufferCommitLowChurn` | low-churn 80×24 glyph field updates through attached buffers | 64 | 0.003 s | 3.472% |
| `testGlyphIndicesLowChurn` | low-churn 80×24 glyph field updates through index arrays | 64 | 0.004 s | 2.353% |
| `testGlyphStringLowChurn` | low-churn 80×24 glyph field updates through string payloads | 64 | 0.002 s | 11.915% |
| `testGlyphStringHighChurn` | high-churn 80×24 glyph field updates through string payloads | 64 | 0.001 s | 0.499% |
| `testLayoutNextLineVariableWidthSequence` | variable-width `layoutNextLine()` flow sequence over one long prepared block | 6 | 0.001 s | 8.116% |
| `testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight` | variable-width `layoutNextLine()` flow sequence over one long prepared block with `anchorToCapHeight` enabled | 6 | 0.001 s | 7.116% |

Raw samples:

```text
testGlyphBufferCommitLowChurn
[0.003241, 0.003443, 0.003304, 0.003228, 0.003429, 0.003273, 0.003308, 0.003384, 0.003621, 0.003472]

testGlyphIndicesLowChurn
[0.003737, 0.003705, 0.003565, 0.003558, 0.003537, 0.003476, 0.003540, 0.003719, 0.003618, 0.003655]

testGlyphStringLowChurn
[0.001669, 0.001904, 0.001734, 0.001643, 0.001259, 0.001326, 0.001523, 0.001525, 0.001450, 0.001441]

testGlyphStringHighChurn
[0.001149, 0.001148, 0.001133, 0.001144, 0.001140, 0.001141, 0.001139, 0.001143, 0.001140, 0.001130]

testLayoutNextLineVariableWidthSequence
[0.000705, 0.000716, 0.000707, 0.000741, 0.000709, 0.000847, 0.000880, 0.000827, 0.000785, 0.000817]

testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
[0.000852, 0.000803, 0.000763, 0.000681, 0.000697, 0.000717, 0.000694, 0.000692, 0.000755, 0.000731]
```

### Android

Environment:

- Date: 2026-04-24 21:39-21:46 EDT
- Device: Pixel 8 Pro AVD
- AVD name: `Pixel_8_Pro`
- Model: `sdk_gphone64_arm64`
- Runtime: Android 14 emulator
- API level: 34
- Build: `releaseAndroidTest`
- Test harness: `androidx.benchmark.junit4.BenchmarkRule`
- Run setup: cold-booted headless AVD; window, transition, and animator scales set to `0`

These numbers came from a full Android rebaseline run of
[`scripts/run-android-performance-tests.sh`](/Users/christian/dev/react-native-pretext/scripts/run-android-performance-tests.sh),
which invokes `connectedReleaseAndroidTest` for the full
[`RNTextEnginePerformanceBenchmark.kt`](/Users/christian/dev/react-native-pretext/android/src/androidTest/java/com/rntextengine/RNTextEnginePerformanceBenchmark.kt)
class and writes AndroidX benchmark summaries beneath
[`android/build/outputs/connected_android_test_additional_output`](/Users/christian/dev/react-native-pretext/android/build/outputs/connected_android_test_additional_output).

These Android numbers are emulator-derived and should be treated as calibration
for relative comparison, not as a substitute for physical-device truth.

#### Prepared Text

| Scenario | Measured block | Inner loop per block | Reported time | Reported allocations |
| --- | --- | ---: | ---: | ---: |
| `preparedBatchCreateChatLifecycle` | prepare 128 chat texts as one batch, then release handles | 2048 | 9,986,905 ns | 823,298 |
| `preparedBatchLayoutReuseChat` | lay out one prepared batch of 128 chat texts | 24 | 68,416 ns | 48 |
| `oneShotMeasureBatchChat` | one-shot measure 128 chat texts | 2 | 7,985,854 ns | 2,864 |
| `prepareInlineRunsLifecycle` | prepare one long styled block with inline runs, then release | 4096 | 17,044,198 ns | 548,866 |

#### Glyph Field and Variable Flow

| Scenario | Measured block | Inner loop per block | Reported time | Reported allocations |
| --- | --- | ---: | ---: | ---: |
| `glyphFieldIndicesLowChurn` | low-churn 80×24 glyph field updates through index arrays | 64 | 136,745 ns | 64 |
| `glyphFieldBufferCommitLowChurn` | low-churn 80×24 glyph field updates through attached buffers | 64 | 740,289 ns | 64 |
| `glyphFieldStringLowChurn` | low-churn 80×24 glyph field updates through string payloads | 64 | 91,101 ns | 64 |
| `glyphFieldStringHighChurn` | high-churn 80×24 glyph field updates through string payloads | 64 | 89,156 ns | 64 |
| `layoutNextLineVariableWidthSequence` | variable-width `layoutNextLine()` flow sequence over one long prepared block | 6 | 37,462 ns | 870 |
| `layoutNextLineVariableWidthSequenceAnchoredToCapHeight` | variable-width `layoutNextLine()` flow sequence over one long prepared block with `anchorToCapHeight` enabled | 6 | 36,879 ns | 870 |

Raw benchmark messages:

```text
preparedBatchCreateChatLifecycle
9,986,905 ns   823,298 allocs

preparedBatchLayoutReuseChat
68,416 ns   48 allocs

oneShotMeasureBatchChat
7,985,854 ns   2,864 allocs

prepareInlineRunsLifecycle
17,044,198 ns   548,866 allocs

glyphFieldIndicesLowChurn
136,745 ns   64 allocs

glyphFieldBufferCommitLowChurn
740,289 ns   64 allocs

glyphFieldStringLowChurn
91,101 ns   64 allocs

glyphFieldStringHighChurn
89,156 ns   64 allocs

layoutNextLineVariableWidthSequence
37,462 ns   870 allocs

layoutNextLineVariableWidthSequenceAnchoredToCapHeight
36,879 ns   870 allocs
```

Run it with:

```sh
./scripts/run-android-performance-tests.sh
./scripts/run-ios-performance-tests.sh
```

When a physical-device Android run is captured, add it beneath this emulator
section instead of replacing it. The emulator results are still useful for
stable relative comparison in CI-like feedback loops.

## What These Numbers Mean

This suite is designed around owner-shaped cost slices:

- prepared batch creation
- prepared layout reuse
- one-shot measure
- inline-run preparation
- variable-width `layoutNextLine` with and without `anchorToCapHeight`
- glyph updates through each public/native mutation mode

The table values are per measured block, not generic one-call latency numbers.
Read them together with the inner-loop count.

The current iOS simulator baseline says:

- prepared batch creation and inline-run preparation are now the dominant measured iOS costs
- prepared full-layout reuse and variable-width `layoutNextLine()` remain in the low-millisecond band because immutable handle queries retain exact answers at the handle owner boundary
- one-shot batch measurement remains steady, with the expected cost of shaping and laying out 128 chat texts immediately
- hidden or not-yet-mounted glyph field mutation no longer manufactures draw rows for every update; all glyph slices now sit in the single-digit millisecond range per measured block
- string glyph updates are now cheaper than attached-buffer commits in this hidden-field harness because they only store compact snapshots until a view needs rows

The current Android emulator baseline says:

- prepared batch creation, prepared layout reuse, one-shot measurement, and inline-run preparation remain broadly aligned with the previous emulator baseline
- the Android benchmark measures the native owner directly rather than the JS/JSI marshalling layer, so it is not expected to expose the recent Android JSI parsing-copy reductions
- glyph string updates are lower in this run, while buffer commits and index updates remain in the same allocation shape
- both variable-width `layoutNextLine()` scenarios remain very light relative to the other benchmark slices and stay aligned in allocation cost

## How to Rebaseline

Type and contract proofs:

```sh
cd examples/android
./gradlew :react-native-text-engine:testDebugUnitTest
```

Android full suite:

```sh
./scripts/run-android-performance-tests.sh
```

iOS full suite:

```sh
IOS_CONFIGURATION=Release ./scripts/run-ios-performance-tests.sh
```

Only update this file after:

- the full Android suite is clean
- the full iOS suite is clean
- no repeated regression pattern remains beyond ordinary run-to-run variance
- any benchmark-harness change is intentional and reflected in this document
