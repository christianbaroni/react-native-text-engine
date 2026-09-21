# Library benchmark results

Latest measurements for each platform. See the [benchmark guide](README.md) for workloads and run instructions.

Each time covers the full repetition count in its row. Chat tests use batches of 128 messages; glyph tests use an 80 × 24 field. Low churn changes a small number of cells; high churn changes the whole field.

## iOS

- iPhone 17 Pro simulator, iOS 26.2
- Xcode 26.3 (`17C529`), Release
- Recorded September 20, 2026, at 21:33 EDT

XCTest elapsed time, averaged over ten samples. Each sample follows an untimed warm-up pass. Handle creation and release are both timed in the preparation tests.

### Prepared text

| Operation                  | Repetitions |    Mean | Relative std. dev. |
| -------------------------- | ----------: | ------: | -----------------: |
| Batch preparation          |        2048 | 0.269 s |             3.501% |
| Prepared batch layout      |          24 | 0.002 s |             6.285% |
| One-shot batch measurement |           2 | 0.010 s |             2.969% |
| Styled text preparation    |        4096 | 0.184 s |             6.378% |

### Glyph fields and text flow

| Operation                              | Repetitions |    Mean | Relative std. dev. |
| -------------------------------------- | ----------: | ------: | -----------------: |
| Glyph buffers, low churn               |          64 | 0.003 s |             5.154% |
| Glyph indices, low churn               |          64 | 0.004 s |            10.533% |
| Glyph strings, low churn               |          64 | 0.002 s |            34.319% |
| Glyph strings, high churn              |          64 | 0.002 s |            33.375% |
| Variable-width flow                    |           6 | 0.001 s |            23.634% |
| Variable-width flow, cap-height anchor |           6 | 0.001 s |            15.634% |

<details>
<summary>iOS samples (seconds)</summary>

```text
testPreparedBatchCreateChatLifecycle
[0.272256, 0.261566, 0.271522, 0.262417, 0.261758, 0.265204, 0.261215, 0.273037, 0.270215, 0.294083]

testPreparedBatchLayoutReuseChat
[0.002204, 0.002086, 0.002017, 0.001973, 0.002153, 0.002004, 0.002222, 0.001915, 0.001794, 0.001959]

testOneShotMeasureBatchChat
[0.010709, 0.010529, 0.011184, 0.010275, 0.010210, 0.010189, 0.010401, 0.010350, 0.010200, 0.010825]

testPrepareInlineRunsLifecycle
[0.179748, 0.183973, 0.203602, 0.209363, 0.187608, 0.177892, 0.175432, 0.175910, 0.177315, 0.173687]
```

```text
testGlyphBufferCommitLowChurn
[0.003612, 0.003260, 0.003256, 0.003257, 0.003261, 0.003228, 0.003766, 0.003283, 0.003312, 0.003299]

testGlyphIndicesLowChurn
[0.003534, 0.004779, 0.003535, 0.003604, 0.003490, 0.003433, 0.003521, 0.003480, 0.003642, 0.003421]

testGlyphStringLowChurn
[0.002827, 0.002871, 0.001339, 0.001328, 0.001426, 0.001422, 0.001419, 0.001420, 0.001419, 0.001436]

testGlyphStringHighChurn
[0.002716, 0.002734, 0.001546, 0.001351, 0.001345, 0.001332, 0.001337, 0.001344, 0.001339, 0.001338]

testLayoutNextLineVariableWidthSequence
[0.001390, 0.000802, 0.000733, 0.000740, 0.000755, 0.000812, 0.000722, 0.000776, 0.000725, 0.000722]

testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
[0.001214, 0.001028, 0.000946, 0.000892, 0.000852, 0.000806, 0.000813, 0.000778, 0.000759, 0.000749]
```

</details>

## Android

- Recorded September 20, 2026, 21:36–21:42 EDT
- Pixel 8 Pro emulator (`Pixel_8_Pro`, `sdk_gphone64_arm64`), Android VanillaIceCream preview / API 34
- React Native 0.87.1, Text Engine 0.3.1, Release instrumentation tests, AndroidX Benchmark
- Cold boot, system animations disabled; all ten benchmarks passed

Times and allocations use AndroidX Benchmark’s console summary: minimum values, truncated to whole units. Handle release is excluded from the preparation timings.

### Prepared text

| Operation                  | Repetitions |          Time | Allocations |
| -------------------------- | ----------: | ------------: | ----------: |
| Batch preparation          |        2048 | 13,207,660 ns |   1,085,441 |
| Prepared batch layout      |          24 |     75,429 ns |       3,095 |
| One-shot batch measurement |           2 |  8,629,515 ns |       2,864 |
| Styled text preparation    |        4096 | 15,771,966 ns |     393,216 |

### Glyph fields and text flow

| Operation                              | Repetitions |       Time | Allocations |
| -------------------------------------- | ----------: | ---------: | ----------: |
| Glyph indices, low churn               |          64 | 141,903 ns |          64 |
| Glyph buffers, low churn               |          64 | 777,739 ns |          64 |
| Glyph strings, low churn               |          64 | 111,478 ns |          64 |
| Glyph strings, high churn              |          64 | 103,724 ns |          64 |
| Variable-width flow                    |           6 |  41,606 ns |         870 |
| Variable-width flow, cap-height anchor |           6 |  41,555 ns |         869 |

<details>
<summary>Android benchmark output</summary>

```text
preparedBatchCreateChatLifecycle
13,207,660 ns   1,085,441 allocs

preparedBatchLayoutReuseChat
75,429 ns   3,095 allocs

oneShotMeasureBatchChat
8,629,515 ns   2,864 allocs

prepareInlineRunsLifecycle
15,771,966 ns   393,216 allocs

glyphFieldIndicesLowChurn
141,903 ns   64 allocs

glyphFieldBufferCommitLowChurn
777,739 ns   64 allocs

glyphFieldStringLowChurn
111,478 ns   64 allocs

glyphFieldStringHighChurn
103,724 ns   64 allocs

layoutNextLineVariableWidthSequence
41,606 ns   870 allocs

layoutNextLineVariableWidthSequenceAnchoredToCapHeight
41,555 ns   869 allocs
```

</details>
