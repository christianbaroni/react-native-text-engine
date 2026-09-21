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

### Memory

2026-09-21T05:50:04.007Z. iPhone 17 Pro simulator, iOS 26.2 (scale 3). Release build; React Native 0.87.1, Text Engine 0.3.1.

Changes from each pass’s baseline, in KiB: median of three process medians ± median absolute deviation. Each process records five passes after two warm-ups. “Released” is the change remaining after dropping the workload and collecting/draining it; it includes allocator and platform caches and is not a leak measurement.

| Workload | Counter | State | Text Engine |
| --- | --- | --- | ---: |
| 128 prepared and laid-out texts | Native heap | Held | 999.8 ± 0.0 |
| 128 prepared and laid-out texts | Native heap | Released | 0.0 ± 0.0 |
| 128 prepared and laid-out texts | Process footprint | Held | 0.0 ± 0.0 |
| 128 prepared and laid-out texts | Process footprint | Released | 0.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Native heap | Held | 332.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Native heap | Released | 0.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Process footprint | Held | 0.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Process footprint | Released | 0.0 ± 0.0 |

Native heap counts malloc allocations in use. Process footprint also reflects non-heap costs such as drawing backing stores; the counters overlap and must not be added.

<details>
<summary>Memory snapshots (bytes)</summary>

| Workload | Implementation | RN configuration | Run | Counter | Baseline | Held | Released |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| prepared_chat | Text Engine | — | 1 | Native heap | 11288608, 11288880, 11288880, 11288880, 11535664 | 12312704, 12312704, 12312704, 12559488, 12559488 | 11288880, 11288880, 11288880, 11535664, 11535664 |
| prepared_chat | Text Engine | — | 1 | Process footprint | 42655424, 42655424, 42655424, 42655424, 44752640 | 42655424, 42655424, 42655424, 44736256, 44752640 | 42655424, 42655424, 42655424, 44752640, 44736256 |
| glyph_fields | Text Engine | — | 1 | Native heap | 11742400, 11742400, 11742400, 11742400, 12004544 | 12082368, 12082368, 12082368, 12344512, 12344512 | 11742400, 11742400, 11742400, 12004544, 12004544 |
| glyph_fields | Text Engine | — | 1 | Process footprint | 46259968, 46259968, 46259968, 46259968, 47685440 | 46259968, 46259968, 46259968, 47701824, 47701824 | 46259968, 46259968, 46259968, 47685440, 47701824 |
| prepared_chat | Text Engine | — | 2 | Native heap | 10798448, 10798272, 10798272, 11045056, 11045056 | 11822032, 11822032, 12068816, 12068816, 12068816 | 10798272, 10798272, 11045056, 11045056, 11045056 |
| prepared_chat | Text Engine | — | 2 | Process footprint | 39902720, 39902720, 39919104, 42032704, 42032704 | 39902720, 39902720, 42032704, 42032704, 42032704 | 39902720, 39902720, 42032704, 42032704, 42032704 |
| glyph_fields | Text Engine | — | 2 | Native heap | 11271760, 11271760, 11271760, 11271760, 11271760 | 11611728, 11611728, 11611728, 11611728, 11611728 | 11271760, 11271760, 11271760, 11271760, 11271760 |
| glyph_fields | Text Engine | — | 2 | Process footprint | 43490880, 43474496, 43458112, 43458112, 43458112 | 43490880, 43474496, 43458112, 43458112, 43458112 | 43474496, 43458112, 43458112, 43458112, 43458112 |
| prepared_chat | Text Engine | — | 3 | Native heap | 11122544, 11369600, 11369600, 11369600, 11354240 | 12393424, 12393424, 12393424, 12378064, 12378064 | 11369600, 11369600, 11369600, 11354240, 11354240 |
| prepared_chat | Text Engine | — | 3 | Process footprint | 39870080, 41918144, 41918144, 41918144, 43589312 | 41918144, 41918144, 41918144, 43589312, 43589312 | 41918144, 41918144, 41918144, 43589312, 43572928 |
| glyph_fields | Text Engine | — | 3 | Native heap | 11384336, 11384336, 11398672, 11398672, 11398672 | 11724304, 11724304, 11738640, 11738640, 11738640 | 11384336, 11384336, 11398672, 11398672, 11398672 |
| glyph_fields | Text Engine | — | 3 | Process footprint | 43589312, 43589312, 43589312, 43589312, 43572928 | 43589312, 43589312, 43605696, 43589312, 43572928 | 43589312, 43589312, 43589312, 43572928, 43572928 |

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

### Memory

2026-09-21T06:00:30.036Z. sdk_gphone64_arm64, Android 14 (API 34, arm64-v8a, density 3). Release build; React Native 0.87.1, Text Engine 0.3.1.

Changes from each pass’s baseline, in KiB: median of three process medians ± median absolute deviation. Each process records five passes after two warm-ups. “Released” is the change remaining after dropping the workload and collecting/draining it; it includes allocator and platform caches and is not a leak measurement.

| Workload | Counter | State | Text Engine |
| --- | --- | --- | ---: |
| 128 prepared and laid-out texts | Native heap | Held | 0.2 ± 0.0 |
| 128 prepared and laid-out texts | Native heap | Released | 0.0 ± 0.0 |
| 128 prepared and laid-out texts | Managed heap | Held | 44.0 ± 0.0 |
| 128 prepared and laid-out texts | Managed heap | Released | 0.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Native heap | Held | 42.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Native heap | Released | 0.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Managed heap | Held | 376.0 ± 0.0 |
| 64 independent 80 × 24 glyph fields | Managed heap | Released | 0.0 ± 0.0 |

Managed heap is sampled after explicit garbage collection, with collection progress checked. Native heap uses the allocator’s allocated-byte counter.

<details>
<summary>Memory snapshots (bytes)</summary>

| Workload | Implementation | RN configuration | Run | Counter | Baseline | Held | Released |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| prepared_chat | Text Engine | — | 1 | Native heap | 16388288, 16442160, 16432432, 16432432, 16432432 | 16388512, 16432656, 16432656, 16432656, 16432720 | 16397792, 16432432, 16432432, 16432432, 16432496 |
| prepared_chat | Text Engine | — | 1 | Managed heap | 2560080, 2850896, 3097152, 3097152, 3101248 | 2601040, 3142208, 3142208, 3142208, 3146304 | 2617424, 3097152, 3097152, 3097152, 3101248 |
| glyph_fields | Text Engine | — | 1 | Native heap | 16562896, 16562896, 16562896, 16562896, 16562896 | 16605904, 16605904, 16605904, 16605904, 16605904 | 16562896, 16562896, 16562896, 16562896, 16562896 |
| glyph_fields | Text Engine | — | 1 | Managed heap | 3105344, 3105344, 3105344, 3109440, 3109440 | 3490368, 3490368, 3494464, 3494464, 3494464 | 3105344, 3105344, 3105344, 3109440, 3109440 |
| prepared_chat | Text Engine | — | 2 | Native heap | 16387888, 16387888, 16399696, 16431824, 16431824 | 16388112, 16388112, 16432048, 16432048, 16432112 | 16387888, 16387888, 16431824, 16431824, 16431888 |
| prepared_chat | Text Engine | — | 2 | Managed heap | 2555984, 2560080, 2625616, 3097152, 3097152 | 2601040, 2601040, 3142208, 3142208, 3142208 | 2555984, 2560080, 3097152, 3097152, 3097152 |
| glyph_fields | Text Engine | — | 2 | Native heap | 16562288, 16562288, 16562288, 16562288, 16562288 | 16605296, 16605296, 16605296, 16605296, 16605296 | 16562288, 16562288, 16562288, 16562288, 16562288 |
| glyph_fields | Text Engine | — | 2 | Managed heap | 3105344, 3105344, 3105344, 3105344, 3109440 | 3490368, 3490368, 3490368, 3490368, 3494464 | 3105344, 3105344, 3105344, 3105344, 3109440 |
| prepared_chat | Text Engine | — | 3 | Native heap | 16387840, 16387840, 16387840, 16431904, 16431808 | 16388064, 16388064, 16397456, 16432032, 16432096 | 16387840, 16387840, 16402384, 16431808, 16431872 |
| prepared_chat | Text Engine | — | 3 | Managed heap | 2555984, 2560080, 2560080, 3101248, 3097152 | 2601040, 2601040, 2650192, 3142208, 3142208 | 2555984, 2560080, 2670672, 3097152, 3097152 |
| glyph_fields | Text Engine | — | 3 | Native heap | 16562272, 16562272, 16562272, 16562272, 16562272 | 16605280, 16605280, 16605280, 16605280, 16605280 | 16562272, 16562272, 16562272, 16562272, 16562272 |
| glyph_fields | Text Engine | — | 3 | Managed heap | 3105344, 3105344, 3105344, 3105344, 3109440 | 3490368, 3490368, 3490368, 3494464, 3494464 | 3105344, 3105344, 3105344, 3105344, 3109440 |

</details>
