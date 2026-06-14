# Performance Tests

These tests are the library's empirical calibration surface.

They are designed around the actual owner model of the system:

- prepared text creation is shaping work
- prepared layout reuse is width-dependent work after shaping
- one-shot measurement is "shape and layout now"
- inline runs add style-merge and attributed-span work
- `layoutNextLine` is the variable-width flow path
- glyph fields have distinct mutation paths with distinct cost profiles

The goal is not to produce one generic "faster/slower" number.
The goal is to expose where time goes, in the same slices where future
optimization decisions will be made.

## Scenarios

### Prepared text

- `preparedBatchCreateChatLifecycle`
  Measures chat-like batch preparation, including explicit handle cleanup.
  This is the shaping/allocation calibration point.

- `preparedBatchLayoutReuseChat`
  Measures repeated width-bound layout over already prepared chat handles.
  This isolates reuse-path layout cost from shaping cost.

- `oneShotMeasureBatchChat`
  Measures repeated one-shot measurement of the same corpus and width.
  This is the direct comparison point against prepared-layout reuse.

- `prepareInlineRunsLifecycle`
  Measures creation of a long styled block with multiple inline runs.
  This captures the extra cost of run parsing, style merging, and span creation.

- `layoutNextLineVariableWidthSequence`
  Measures the per-line flow path over one long prepared block with changing widths.
  This is the calibration point for obstacle-flow and editorial use cases.

### Glyph fields

- `glyphIndicesLowChurn`
  Alternates between two index states with limited cell churn.
  This is the primary dirty-row reuse scenario.

- `glyphBufferCommitLowChurn`
  Uses attached buffers plus `commitGlyphFieldBuffers()` with the same churn pattern.
  This isolates the lowest-overhead native commit path.

- `glyphStringLowChurn`
  Alternates between two string states with limited cell churn.
  This shows whether the legacy/public string path is still paying whole-field
  rebuild cost or is actually deleting unchanged row work.

- `glyphStringHighChurn`
  Alternates between two fully changed string states.
  This is the worst-case legacy/public string update path.

## Tooling

- iOS uses XCTest performance measurement in the example test target.
  It measures the public JSI contract directly on a Hermes runtime installed in the test.

- Android uses `androidx.benchmark.junit4.BenchmarkRule` in instrumentation tests.
  It measures the real Android text-engine owner on a release test build.

This split is intentional:

- iOS can cheaply exercise the full JSI path inside XCTest.
- Android benchmark tooling is strongest when measuring the native owner on-device.

## Run

### iOS

Boot a simulator, then run:

```sh
yarn perf:ios
```

Or pick a specific simulator:

```sh
IOS_DESTINATION_ID=<simulator-id> yarn perf:ios
```

The iOS runner executes two targeted batches:

- prepared-text scenarios
- glyph-field plus `layoutNextLine` scenarios

That split is deliberate. It keeps each simulator run short enough for local iteration
while still covering the full scenario set.

### Android

Connect a device or boot an emulator, then run:

```sh
yarn perf:android
```

If you only need to verify that the Android benchmark suite compiles:

```sh
cd examples/android
./gradlew :react-native-text-engine:assembleReleaseAndroidTest
```

## How To Read Results

Read the suite by comparison, not by isolated numbers.

Useful comparisons:

- prepared layout reuse vs one-shot measurement
- inline-run preparation vs plain preparation
- low-churn index updates vs low-churn buffer commits
- low-churn string updates vs high-churn string updates
- low-churn glyph updates vs high-churn string updates

Those comparisons tell you where work is being saved or merely moved.

If an optimization claims to help one owner path, rerun the matching scenario.
If it regresses a neighboring scenario, the optimization is probably hiding cost
instead of deleting it.
