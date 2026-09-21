# TextView and PreparedTextView vs React Native Text

This benchmark compares native layout, mounting, first drawing, and held/released memory in TextView, PreparedTextView, and React Native's `Text` on iOS and Android. It also compares TextView and RN Text measurement. Each platform uses the same text, styles, and widths across implementations. [View results](results.md).

## Run

```sh
# iOS: boot a simulator first.
yarn perf:compare:ios

# Android: connect a device or start an emulator first.
yarn perf:compare:android
```

Each command builds the tests in Release. iOS runs three separate processes. Android runs each implementation in three separate processes with the default RN layout and three with `enablePreparedTextLayout`. Implementation order rotates between repetitions; Android configuration order alternates. The timing runs use 18 Android processes in total. Memory adds nine isolated processes on iOS and 18 on Android, with the same order rotation and Android flag configurations. The runner updates its platform’s section in [results.md](results.md) after all required timing and memory runs pass. `BENCHMARK_MEMORY_ONLY=1` runs only memory and preserves the existing timing results. A failed run leaves the existing results unchanged.

Set `IOS_DESTINATION_ID` to select an iOS simulator or connected physical device by UDID, or `ANDROID_SERIAL` to select an Android device. Xcode selects the iOS SDK from the destination. Physical iOS devices must be unlocked, have Developer Mode enabled, and have signing configured for the example and test targets in Xcode. The test installs the example app on the selected device.

Android uses the example’s Java and SDK setup and compiles the test APK ahead of time with ART’s `speed` mode. The build uses Node from `PATH`, or the executable specified by `NODE_BINARY`.

## What is measured

| Test                                      | Work per pass                                                                                                                    |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                          | Build and lay out a Fabric shadow tree for 128 messages, then release it.                                                        |
| Native layout, mount, and first draw      | Build and lay out the same tree, create each native view through its production props/state path, draw it once, then release it. |
| Retained paragraph measurement            | Remeasure the same 128 paragraph nodes at unchanged width constraints and unconstrained height.                                  |
| Short labels, natural line height         | Create, measure, and release 128 distinct Latin, emoji, Japanese, and Bengali labels without an explicit line height.            |
| Plain text creation and layout            | Create, measure, and release 128 distinct paragraphs.                                                                            |
| Manager queries, 200 keys                 | Query 50 previously measured texts at four widths, filling RN’s prepared-layout cache.                                           |
| Manager queries, 200 keys, two-line limit | Repeat the 200-key queries with truncation after two lines.                                                                      |
| Manager queries, 768 keys                 | Query 128 previously measured texts at six widths.                                                                               |
| Manager queries, 768 keys, two-line limit | Repeat the manager queries with truncation after two lines.                                                                      |
| Styled text creation and layout           | Create, measure, and release 96 texts with changes in font size, weight, style, letter spacing, and tabular numbers.             |

The two component-lifecycle rows include all three implementations. PreparedTextView receives a caller-owned handle and explicit dimensions: each timed pass prepares every paragraph separately, queries its height at the shared wrapping width, constructs its fixed-size Fabric node, and releases the handle after disposing of the tree and views. Preparation and the first query are included; handles are neither prewarmed nor shared across paragraphs or passes. Batch preparation is covered by the separate [library benchmark](../library/README.md).

The remaining rows compare RN Text and TextView. PreparedTextView has no paragraph measurement manager or retained-node measurement operation: its dimensions come from the caller's explicit layout query.

The paragraph fixtures are English with explicit line heights; the short-label fixtures exercise natural font and fallback-font metrics. Android uses font weights 400 and 700 and sizes that map to whole pixels across implementations; the test stops if the device density cannot represent those sizes exactly. Creation includes input construction and cleanup. Manager queries reuse text inputs and layout managers; retained-paragraph measurements also reuse the existing shadow nodes.

The first-draw row includes native measurement, view construction, mounting updates, and CPU drawing. iOS produces the native text layers' backing stores; Android draws the native views into a reusable software canvas. Main-thread dispatch and validation bitmap allocation are outside the timed batches. React/JavaScript execution, compositor presentation, and scrolling are outside these measurements.

## Method

Each run starts a new process without the example UI. Each implementation is measured nine times after warm-up: two samples on iOS, ten on Android. On iOS, implementation order rotates within each process (alternating for two-way rows). Android uses separate processes so the timed workloads do not interleave allocations from different implementations in one heap. Each creation, list-layout, or first-draw sample contains four passes. Retained-paragraph samples contain 128 passes on both platforms. Manager-query samples contain 128 passes on iOS and eight on Android; the Android count keeps prepared-cache misses practical to measure.

On iOS, all three implementations include object release and autorelease-pool cleanup in creation, list-layout, and first-draw timings. First-draw timings also include flushing Core Animation after releasing the views, allowing their offscreen backing stores to be freed before the next pass. Android releases prepared handles within the timed work; managed objects are garbage-collected normally.

Before timing, the test checks every measured text and width combination, including truncation, inline styles, and natural-height labels. Mounted views must contain the expected text and produce nonblank text within their measured bounds; iOS also checks that the drawing layers have backing stores at the device scale. Heights and Fabric frames must agree within one device pixel. Android also checks line breaks and single-line glyph widths. Widths must fit their constraints: React Native can report the full container width for wrapped text, while TextView reports the width used by the glyphs.

Each results table shows the median of its three run medians, with median absolute deviation to show variation between runs. All recorded samples are available below the table.

## Memory workloads

The memory comparison retains 128 laid-out paragraph nodes, then separately measures the same population with 128 drawn native views also held alive. Both include their layout managers and caches. PreparedTextView includes all caller-owned preparation handles. Views are created through the same props/state path as the first-draw timing; the held iOS views retain their drawn backing stores. Android draws into the same shared software canvas as its timing workload, allocated before the baseline.

The workload releases views, trees, registries, and public handles before the released snapshot. Memory is measured in separate processes so collection and heap residency do not affect the timing passes. See the [counter definitions and sampling method](../README.md#memory).

## Android prepared layout

RN 0.87.1 implements `enablePreparedTextLayout` on Android. The flag is set before RN initialization in each process. The Fabric workload uses RN's own paragraph-node integration; direct queries use `prepareLayout` followed by `measurePreparedLayout` with matching constraints. Validation inspects the prepared Android layout's actual line breaks and glyph widths.

The manager-query workloads visit 50 texts at four widths (200 keys) and 128 texts at six widths (768 keys). The smaller workload uses the first 50 paragraphs and first four widths from the larger one. RN's default measurement cache holds 1,024 entries; its prepared-layout cache holds 200. After warm-up, the 200-key workload hits the cache in either configuration. The 768-key workload fits the default measurement cache but misses the prepared-layout cache on every query. Each working set and line-limit case uses a separate RN manager; the prepared cache size stays at its default.

Before timing each Android prepared-RN query case, the test retains the layouts from one complete pass and checks their identities on the next pass: every 200-key layout must be reused, and every 768-key layout must be replaced. It then releases those validation references. Timed queries still call `prepareLayout` and `measurePreparedLayout`; they do not bypass the cache by using retained layouts directly. The retained-paragraph row separately tests RN paragraph nodes’ own layout reuse.

Default and prepared results each include independently measured TextView and PreparedTextView controls. The first-draw workload exercises RN’s reuse of its prepared Android layout for drawing. In prepared mode, the retained-paragraph workload exercises the paragraph node’s own result reuse. iOS has no prepared-layout implementation in RN 0.87.1 and retains its ordinary comparison.

## Source

PreparedTextView uses the public handle lifecycle. On iOS, the benchmark invokes the installed preparation host function from C++, including its JSI string/style parsing; the Hermes runtime and immutable string/style fixtures are created outside timing, and no JavaScript is evaluated. Queries and release use the same native handle owners as the public API. Android calls the public preparation, layout, and release backends through JNI. It does not substitute TextView's private measurement handles, which have different layout-transfer behavior.

The [iOS test](../../examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm) and [Android test](../../android/src/nativeTest/jni/RNTextEngineTextComparison.cpp) call the platforms’ C++ layout managers and build Fabric shadow trees. On Android, this includes RN’s C++ layout cache; calling its Java layout methods directly would bypass that cache.

The [iOS runner](../run-ios-comparison.sh) and [Android runner](../run-android-comparison.sh) save each run under `benchmarks/.results/`. The [report script](../report.mts) checks the logs and updates the results.
