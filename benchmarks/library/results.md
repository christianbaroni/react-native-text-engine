# Library benchmark results

Recorded on April 24, 2026. See the [benchmark guide](README.md) for workloads and run instructions.

Each time covers the full repetition count in its row. Chat tests use batches of 128 messages; glyph tests use an 80 × 24 field. Low churn changes a small number of cells; high churn changes the whole field.

## iOS

- iPhone 17 Pro simulator, iOS 26.2
- Xcode 26.3 (`17C529`), Release
- Recorded at 21:38 EDT

XCTest elapsed time, averaged over ten samples. Each sample follows an untimed warm-up pass. Handle creation and release are both timed in the preparation tests.

### Prepared text

| Operation                  | Repetitions |    Mean | Relative std. dev. |
| -------------------------- | ----------: | ------: | -----------------: |
| Batch preparation          |        2048 | 0.301 s |             1.171% |
| Prepared batch layout      |          24 | 0.002 s |             4.034% |
| One-shot batch measurement |           2 | 0.011 s |             1.319% |
| Styled text preparation    |        4096 | 0.203 s |             0.701% |

### Glyph fields and text flow

| Operation                              | Repetitions |    Mean | Relative std. dev. |
| -------------------------------------- | ----------: | ------: | -----------------: |
| Glyph buffers, low churn               |          64 | 0.003 s |             3.472% |
| Glyph indices, low churn               |          64 | 0.004 s |             2.353% |
| Glyph strings, low churn               |          64 | 0.002 s |            11.915% |
| Glyph strings, high churn              |          64 | 0.001 s |             0.499% |
| Variable-width flow                    |           6 | 0.001 s |             8.116% |
| Variable-width flow, cap-height anchor |           6 | 0.001 s |             7.116% |

<details>
<summary>iOS samples (seconds)</summary>

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

</details>

## Android

- Pixel 8 Pro emulator (`Pixel_8_Pro`, `sdk_gphone64_arm64`), Android 14 / API 34
- Release instrumentation tests, AndroidX Benchmark
- Recorded at 21:39–21:46 EDT after a cold boot, with system animations disabled

Times and allocations are reported by AndroidX Benchmark. Handle release is excluded from the preparation timings.

### Prepared text

| Operation                  | Repetitions |          Time | Allocations |
| -------------------------- | ----------: | ------------: | ----------: |
| Batch preparation          |        2048 |  9,986,905 ns |     823,298 |
| Prepared batch layout      |          24 |     68,416 ns |          48 |
| One-shot batch measurement |           2 |  7,985,854 ns |       2,864 |
| Styled text preparation    |        4096 | 17,044,198 ns |     548,866 |

### Glyph fields and text flow

| Operation                              | Repetitions |       Time | Allocations |
| -------------------------------------- | ----------: | ---------: | ----------: |
| Glyph indices, low churn               |          64 | 136,745 ns |          64 |
| Glyph buffers, low churn               |          64 | 740,289 ns |          64 |
| Glyph strings, low churn               |          64 |  91,101 ns |          64 |
| Glyph strings, high churn              |          64 |  89,156 ns |          64 |
| Variable-width flow                    |           6 |  37,462 ns |         870 |
| Variable-width flow, cap-height anchor |           6 |  36,879 ns |         870 |

<details>
<summary>Android benchmark output</summary>

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

</details>
