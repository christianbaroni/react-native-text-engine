# TextView vs React Native Text

This benchmark compares native text layout in TextView and React Native's `Text` on iOS and Android. Each platform compares the same text, styles, and widths in both implementations. [View results](results.md).

## Run

```sh
# iOS: boot a simulator first.
yarn perf:compare:ios

# Android: connect a device or start an emulator first.
yarn perf:compare:android
```

Each command builds the tests in Release. iOS runs three separate processes. Android runs three processes with the default RN layout and three with `enablePreparedTextLayout`, alternating configuration order between repetitions. It updates its platform’s section in [results.md](results.md) after all required runs pass. A failed run leaves the existing results unchanged.

Set `IOS_DESTINATION_ID` to select an iOS simulator or connected physical device by UDID, or `ANDROID_SERIAL` to select an Android device. Xcode selects the iOS SDK from the destination. Physical iOS devices must be unlocked, have Developer Mode enabled, and have signing configured for the example and test targets in Xcode. The test installs the example app on the selected device.

Android uses the example’s Java and SDK setup and compiles the test APK ahead of time with ART’s `speed` mode. The build uses Node from `PATH`, or the executable specified by `NODE_BINARY`.

## What is measured

| Test                             | Work per pass                                                                                                        |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                 | Build and lay out a Fabric shadow tree for 128 messages, then release it.                                            |
| Plain text creation and layout   | Create, measure, and release 128 distinct texts.                                                                     |
| Repeated layout queries          | Query previously measured text at six widths.                                                                        |
| Repeated queries, two-line limit | Repeat the queries with truncation after two lines.                                                                  |
| Styled text creation and layout  | Create, measure, and release 96 texts with changes in font size, weight, style, letter spacing, and tabular numbers. |

The strings are English, with fixed font sizes and uniform paragraph line heights. Android uses font weights 400 and 700 and sizes that map to whole pixels in both implementations; the test stops if the device density cannot represent those sizes exactly. The creation tests include input construction and cleanup. Repeated queries reuse text inputs and layout managers. These are native layout timings; React rendering, drawing, and scrolling are outside the measurement.

## Method

Each run starts a new process without the example UI. Each implementation is measured nine times after warm-up: two samples on iOS, ten on Android. The order alternates so neither implementation consistently runs first. Each creation or list-layout sample contains four passes. Repeated-query samples contain 128 passes on iOS and eight on Android; the Android count keeps prepared-cache misses practical to measure. iOS timing includes autorelease-pool cleanup. Android releases prepared handles within the timed work; managed objects are garbage-collected normally.

Before timing, the test checks all text and width combinations, including truncation and inline styles. Heights and Fabric frames must agree within one device pixel. Android also checks line breaks and single-line glyph widths. Widths must fit their constraints: React Native can report the full container width for wrapped text, while TextView reports the width used by the glyphs.

Each results table shows the median of its three run medians, with median absolute deviation to show variation between runs. All recorded samples are available below the table.

## Android prepared layout

RN 0.87.1 implements `enablePreparedTextLayout` on Android. The flag is set before RN initialization in each process. The Fabric workload uses RN's own paragraph-node integration; direct queries use `prepareLayout` followed by `measurePreparedLayout` with matching constraints. Validation inspects the prepared Android layout's actual line breaks and glyph widths.

The repeated-query workload visits 128 texts at six widths: 768 cache keys. RN's default measurement cache holds 1,024 entries, while its prepared-layout cache holds 200. These rows therefore measure cache misses in prepared mode, not repeated measurements of a retained paragraph node. RN paragraph nodes separately retain their measured layouts. The prepared cache size is left at its default.

Default and prepared results each retain their paired TextView measurements. The flag also lets RN reuse the prepared Android layout for drawing; these layout workloads measure the work that creates and measures it. iOS has no prepared-layout implementation in RN 0.87.1 and retains its ordinary comparison.

## Source

The [iOS test](../../examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm) and [Android test](../../android/src/androidTest/jni/RNTextEngineTextComparison.cpp) call the platforms’ C++ layout managers and build Fabric shadow trees. On Android, this includes RN’s C++ layout cache; calling its Java layout methods directly would bypass that cache.

The [iOS runner](../run-ios-comparison.sh) and [Android runner](../run-android-comparison.sh) save each run under `benchmarks/.results/`. The [report script](../report.mjs) checks the logs and updates the results.
