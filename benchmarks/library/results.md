# Library benchmark results

Latest measurements for each platform. See the [benchmark guide](README.md) for workloads and run instructions.

Each time covers the full repetition count in its row. Chat tests use batches of 128 messages; glyph tests use an 80 × 24 field. Low churn changes a small number of cells; high churn changes the whole field.

## iOS

- iPhone 17 Pro simulator, iOS 26.2
- Xcode 26.3 (`17C529`), Release
- Recorded September 20, 2026, at 06:43 EDT

XCTest elapsed time, averaged over ten samples. Each sample follows an untimed warm-up pass. Handle creation and release are both timed in the preparation tests.

### Prepared text

| Operation                  | Repetitions |    Mean | Relative std. dev. |
| -------------------------- | ----------: | ------: | -----------------: |
| Batch preparation          |        2048 | 0.268 s |             0.615% |
| Prepared batch layout      |          24 | 0.002 s |            26.859% |
| One-shot batch measurement |           2 | 0.011 s |            17.676% |
| Styled text preparation    |        4096 | 0.177 s |             1.299% |

### Glyph fields and text flow

| Operation                              | Repetitions |    Mean | Relative std. dev. |
| -------------------------------------- | ----------: | ------: | -----------------: |
| Glyph buffers, low churn               |          64 | 0.003 s |             1.906% |
| Glyph indices, low churn               |          64 | 0.005 s |            30.345% |
| Glyph strings, low churn               |          64 | 0.002 s |            21.403% |
| Glyph strings, high churn              |          64 | 0.002 s |            18.531% |
| Variable-width flow                    |           6 | 0.001 s |             2.620% |
| Variable-width flow, cap-height anchor |           6 | 0.001 s |            29.856% |

<details>
<summary>iOS samples (seconds)</summary>

```text
testPreparedBatchCreateChatLifecycle
[0.268332, 0.267184, 0.266629, 0.268842, 0.267588, 0.268579, 0.266786, 0.272235, 0.266827, 0.269838]

testPreparedBatchLayoutReuseChat
[0.003481, 0.002714, 0.002340, 0.001969, 0.001927, 0.001773, 0.001836, 0.001663, 0.001648, 0.001634]

testOneShotMeasureBatchChat
[0.016678, 0.012454, 0.011002, 0.010233, 0.010281, 0.010145, 0.010141, 0.010139, 0.010124, 0.010243]

testPrepareInlineRunsLifecycle
[0.180020, 0.176504, 0.181802, 0.177149, 0.174500, 0.175578, 0.177424, 0.174032, 0.175305, 0.176412]
```

```text
testGlyphBufferCommitLowChurn
[0.003324, 0.003236, 0.003239, 0.003307, 0.003294, 0.003242, 0.003231, 0.003153, 0.003133, 0.003169]

testGlyphIndicesLowChurn
[0.008204, 0.006161, 0.005025, 0.004727, 0.004271, 0.003983, 0.003776, 0.003645, 0.003517, 0.003452]

testGlyphStringLowChurn
[0.003028, 0.003249, 0.002659, 0.002305, 0.002260, 0.002101, 0.001918, 0.001919, 0.001784, 0.001784]

testGlyphStringHighChurn
[0.002888, 0.002553, 0.002285, 0.002029, 0.002055, 0.001923, 0.001836, 0.001755, 0.001653, 0.001666]

testLayoutNextLineVariableWidthSequence
[0.000758, 0.000762, 0.000754, 0.000747, 0.000718, 0.000715, 0.000714, 0.000716, 0.000716, 0.000723]

testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
[0.001806, 0.001389, 0.001107, 0.001031, 0.000967, 0.000897, 0.000848, 0.000808, 0.000797, 0.000763]
```

</details>

## Android

- Recorded September 20, 2026, 06:37–06:43 EDT
- Pixel 8 Pro emulator (`Pixel_8_Pro`, `sdk_gphone64_arm64`), Android VanillaIceCream preview / API 34
- React Native 0.87.1, Text Engine 0.2.0, Release instrumentation tests, AndroidX Benchmark
- Cold boot, system animations disabled; all ten benchmarks passed

Times and allocations use AndroidX Benchmark’s console summary: minimum values, truncated to whole units. Handle release is excluded from the preparation timings.

### Prepared text

| Operation                  | Repetitions |          Time | Allocations |
| -------------------------- | ----------: | ------------: | ----------: |
| Batch preparation          |        2048 | 11,120,260 ns |   1,085,440 |
| Prepared batch layout      |          24 |     60,524 ns |       3,096 |
| One-shot batch measurement |           2 |  8,103,416 ns |       2,864 |
| Styled text preparation    |        4096 | 15,394,326 ns |     446,464 |

### Glyph fields and text flow

| Operation                              | Repetitions |       Time | Allocations |
| -------------------------------------- | ----------: | ---------: | ----------: |
| Glyph indices, low churn               |          64 | 136,645 ns |          64 |
| Glyph buffers, low churn               |          64 | 737,703 ns |          64 |
| Glyph strings, low churn               |          64 |  84,959 ns |          64 |
| Glyph strings, high churn              |          64 |  88,239 ns |          64 |
| Variable-width flow                    |           6 |  37,824 ns |         870 |
| Variable-width flow, cap-height anchor |           6 |  38,633 ns |         870 |

<details>
<summary>Android benchmark output</summary>

```text
preparedBatchCreateChatLifecycle
11,120,260 ns   1,085,440 allocs

preparedBatchLayoutReuseChat
60,524 ns   3,096 allocs

oneShotMeasureBatchChat
8,103,416 ns   2,864 allocs

prepareInlineRunsLifecycle
15,394,326 ns   446,464 allocs

glyphFieldIndicesLowChurn
136,645 ns   64 allocs

glyphFieldBufferCommitLowChurn
737,703 ns   64 allocs

glyphFieldStringLowChurn
84,959 ns   64 allocs

glyphFieldStringHighChurn
88,239 ns   64 allocs

layoutNextLineVariableWidthSequence
37,824 ns   870 allocs

layoutNextLineVariableWidthSequenceAnchoredToCapHeight
38,633 ns   870 allocs
```

</details>
