# Library benchmark results

Latest measurements for each platform. See the [benchmark guide](README.md) for workloads and run instructions.

Each time covers the full repetition count in its row. Chat tests use batches of 128 messages; glyph tests use an 80 × 24 field. Low churn changes a small number of cells; high churn changes the whole field.

## iOS

- iPhone 17 Pro simulator, iOS 26.2
- Xcode 26.3 (`17C529`), Release
- Recorded September 20, 2026, at 16:02 EDT

XCTest elapsed time, averaged over ten samples. Each sample follows an untimed warm-up pass. Handle creation and release are both timed in the preparation tests.

### Prepared text

| Operation                  | Repetitions |    Mean | Relative std. dev. |
| -------------------------- | ----------: | ------: | -----------------: |
| Batch preparation          |        2048 | 0.271 s |             1.079% |
| Prepared batch layout      |          24 | 0.002 s |            20.052% |
| One-shot batch measurement |           2 | 0.011 s |             2.171% |
| Styled text preparation    |        4096 | 0.177 s |             0.946% |

### Glyph fields and text flow

| Operation                              | Repetitions |    Mean | Relative std. dev. |
| -------------------------------------- | ----------: | ------: | -----------------: |
| Glyph buffers, low churn               |          64 | 0.003 s |             3.696% |
| Glyph indices, low churn               |          64 | 0.004 s |            17.030% |
| Glyph strings, low churn               |          64 | 0.002 s |            18.841% |
| Glyph strings, high churn              |          64 | 0.002 s |             9.479% |
| Variable-width flow                    |           6 | 0.001 s |            26.072% |
| Variable-width flow, cap-height anchor |           6 | 0.001 s |            24.591% |

<details>
<summary>iOS samples (seconds)</summary>

```text
testPreparedBatchCreateChatLifecycle
[0.268205, 0.277011, 0.273589, 0.270030, 0.274290, 0.269707, 0.270607, 0.269438, 0.267751, 0.268110]

testPreparedBatchLayoutReuseChat
[0.002878, 0.002277, 0.002024, 0.001842, 0.001817, 0.001689, 0.001686, 0.001592, 0.001668, 0.001588]

testOneShotMeasureBatchChat
[0.010806, 0.010681, 0.010535, 0.010377, 0.010353, 0.010382, 0.011096, 0.010411, 0.010414, 0.010452]

testPrepareInlineRunsLifecycle
[0.176495, 0.176786, 0.176007, 0.176500, 0.181491, 0.176498, 0.176395, 0.177552, 0.174905, 0.175907]
```

```text
testGlyphBufferCommitLowChurn
[0.003433, 0.003415, 0.003353, 0.003491, 0.003372, 0.003284, 0.003791, 0.003472, 0.003461, 0.003463]

testGlyphIndicesLowChurn
[0.005874, 0.004967, 0.004661, 0.004199, 0.004013, 0.003855, 0.003739, 0.003633, 0.003728, 0.003412]

testGlyphStringLowChurn
[0.002847, 0.002996, 0.002615, 0.002467, 0.001906, 0.002126, 0.002040, 0.001887, 0.001851, 0.001766]

testGlyphStringHighChurn
[0.001785, 0.001743, 0.001705, 0.001624, 0.001618, 0.001455, 0.001448, 0.001410, 0.001408, 0.001370]

testLayoutNextLineVariableWidthSequence
[0.001665, 0.001199, 0.001077, 0.000988, 0.000950, 0.000869, 0.000836, 0.000795, 0.000785, 0.000779]

testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
[0.001571, 0.001385, 0.001175, 0.001084, 0.000979, 0.000904, 0.000839, 0.000834, 0.000811, 0.000775]
```

</details>

## Android

- Recorded September 20, 2026, 16:05–16:09 EDT
- Pixel 8 Pro emulator (`Pixel_8_Pro`, `sdk_gphone64_arm64`), Android VanillaIceCream preview / API 34
- React Native 0.87.1, Text Engine 0.3.0, Release instrumentation tests, AndroidX Benchmark
- Cold boot, system animations disabled; all ten benchmarks passed

Times and allocations use AndroidX Benchmark’s console summary: minimum values, truncated to whole units. Handle release is excluded from the preparation timings.

### Prepared text

| Operation                  | Repetitions |          Time | Allocations |
| -------------------------- | ----------: | ------------: | ----------: |
| Batch preparation          |        2048 | 11,218,480 ns |   1,085,441 |
| Prepared batch layout      |          24 |     60,661 ns |       3,096 |
| One-shot batch measurement |           2 |  8,070,243 ns |       2,864 |
| Styled text preparation    |        4096 | 14,045,260 ns |     393,216 |

### Glyph fields and text flow

| Operation                              | Repetitions |       Time | Allocations |
| -------------------------------------- | ----------: | ---------: | ----------: |
| Glyph indices, low churn               |          64 | 136,497 ns |          64 |
| Glyph buffers, low churn               |          64 | 779,703 ns |          64 |
| Glyph strings, low churn               |          64 |  88,359 ns |          64 |
| Glyph strings, high churn              |          64 |  89,962 ns |          64 |
| Variable-width flow                    |           6 |  39,775 ns |         870 |
| Variable-width flow, cap-height anchor |           6 |  38,862 ns |         870 |

<details>
<summary>Android benchmark output</summary>

```text
preparedBatchCreateChatLifecycle
11,218,480 ns   1,085,441 allocs

preparedBatchLayoutReuseChat
60,661 ns   3,096 allocs

oneShotMeasureBatchChat
8,070,243 ns   2,864 allocs

prepareInlineRunsLifecycle
14,045,260 ns   393,216 allocs

glyphFieldIndicesLowChurn
136,497 ns   64 allocs

glyphFieldBufferCommitLowChurn
779,703 ns   64 allocs

glyphFieldStringLowChurn
88,359 ns   64 allocs

glyphFieldStringHighChurn
89,962 ns   64 allocs

layoutNextLineVariableWidthSequence
39,775 ns   870 allocs

layoutNextLineVariableWidthSequenceAnchoredToCapHeight
38,862 ns   870 allocs
```

</details>
