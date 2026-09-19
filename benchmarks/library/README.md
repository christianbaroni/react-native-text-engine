# Library benchmarks

These benchmarks measure text preparation, layout, and glyph updates in the engine. [View results](results.md).

## Run

```sh
# iOS: boot a simulator first.
yarn perf:ios

# Android: connect a device or start an emulator first.
yarn perf:android
```

Both commands use Release builds. Set `IOS_DESTINATION_ID` to select an iOS simulator. `IOS_CONFIGURATION=Debug` is available for debugging the tests.

To compile the Android tests without running them:

```sh
cd examples/android
./gradlew :react-native-text-engine:assembleReleaseAndroidTest
```

## What is measured

| Operation               | Work measured                                                                                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Batch preparation       | Prepare 128 chat messages.                                                                                                                                              |
| Prepared layout         | Measure the same batch using existing prepared handles.                                                                                                                 |
| One-shot measurement    | Prepare and measure a batch of 128 messages in one call.                                                                                                                |
| Styled text preparation | Prepare a long text with inline styles.                                                                                                                                 |
| Variable-width flow     | Lay out a long text one line at a time at changing widths, with and without cap-height anchoring.                                                                       |
| Glyph updates           | Update an 80 × 24 field through index arrays, attached buffers, or strings. Most tests change a small number of cells; a separate string test changes the entire field. |

The [iOS tests](../../examples/ios/exampleTests/RNTextEnginePerformanceTests.mm) call the engine through JSI and Hermes and use XCTest to measure elapsed time. The [Android tests](../../android/src/androidTest/java/com/rntextengine/RNTextEnginePerformanceBenchmark.kt) call the native implementation and use AndroidX Benchmark to measure time and allocations. Android excludes handle release from preparation timings. Compare each platform with earlier runs of the same suite.

## Recording results

After running the full suite on a platform, replace its section in [results.md](results.md) with the date, device, build configuration, and measurements. Keep only the latest run for each platform.

Console logs are saved under `benchmarks/.results/`. AndroidX also writes detailed reports under `android/build/outputs/connected_android_test_additional_output/`.
