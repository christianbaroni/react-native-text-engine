# TextView vs React Native Text

This benchmark compares native text layout in TextView and React Native's `Text` on iOS and Android. Each platform compares the same text, styles, and widths in both implementations. [View results](results.md).

## Run

```sh
# iOS: boot a simulator first.
yarn perf:compare:ios

# Android: connect a device or start an emulator first.
yarn perf:compare:android
```

Each command builds the tests in Release and runs them in three separate processes. It updates its platform’s section in [results.md](results.md) after all three runs pass. A failed run leaves the existing results unchanged.

Set `IOS_DESTINATION_ID` to select an iOS simulator or connected physical device by UDID, or `ANDROID_SERIAL` to select an Android device. Xcode selects the iOS SDK from the destination. Physical iOS devices must be unlocked, have Developer Mode enabled, and have signing configured for the example and test targets in Xcode. The test installs the example app on the selected device.

Android uses the example’s Java and SDK setup and compiles the test APK ahead of time with ART’s `speed` mode. The build uses Node from `PATH`, or the executable specified by `NODE_BINARY`.

## What is measured

| Test                            | Work per pass                                                                                                        |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                | Build and lay out a Fabric shadow tree for 128 messages, then release it.                                            |
| Plain text creation and layout  | Create, measure, and release 128 distinct texts.                                                                     |
| Cached layout                   | Query previously measured text at six widths.                                                                        |
| Cached layout, two-line limit   | Repeat the cached queries with truncation after two lines.                                                           |
| Styled text creation and layout | Create, measure, and release 96 texts with changes in font size, weight, style, letter spacing, and tabular numbers. |

The strings are English, with fixed font sizes and uniform paragraph line heights. Android uses font weights 400 and 700 and sizes that map to whole pixels in both implementations; the test stops if the device density cannot represent those sizes exactly. The creation tests include input construction and cleanup. Cached tests reuse prepared inputs and saved measurements. These are native layout timings; React rendering, drawing, and scrolling are outside the measurement.

## Method

Each run starts a new process without the example UI. Each implementation is measured nine times after warm-up: two samples on iOS, ten on Android. The order alternates so neither implementation consistently runs first. Each creation or list-layout sample contains four passes; each cached sample contains 128. iOS timing includes autorelease-pool cleanup. Android releases prepared handles within the timed work; managed objects are garbage-collected normally.

Before timing, the test checks all text and width combinations, including truncation and inline styles. Heights and Fabric frames must agree within one device pixel. Android also checks line breaks and single-line glyph widths. Widths must fit their constraints: React Native can report the full container width for wrapped text, while TextView reports the width used by the glyphs.

The results table shows the median of the three run medians, with median absolute deviation to show variation between runs. All recorded samples are available below the table.

## Source

The [iOS test](../../examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm) and [Android test](../../android/src/androidTest/jni/RNTextEngineTextComparison.cpp) call the platforms’ C++ layout managers and build Fabric shadow trees. On Android, this includes RN’s C++ layout cache; calling its Java layout methods directly would bypass that cache.

The [iOS runner](../run-ios-comparison.sh) and [Android runner](../run-android-comparison.sh) save each run under `benchmarks/.results/`. The [report script](../report.mjs) checks the logs and updates the results.
