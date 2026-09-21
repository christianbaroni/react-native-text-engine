# Library benchmarks

These benchmarks measure text preparation, layout, glyph updates, and held/released memory in the engine. [View results](results.md).

## Run

```sh
# iOS: boot a simulator first.
yarn perf:ios

# Android: connect a device or start an emulator first.
yarn perf:android
```

Both commands use Release builds and add three separate memory processes. Use `BENCHMARK_MEMORY_ONLY=1` to refresh memory alone. Set `IOS_DESTINATION_ID` to select an iOS simulator. `IOS_CONFIGURATION=Debug` is available for debugging the tests; Debug runs do not update the memory report.

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

## Memory workloads

The memory passes retain a batch of 128 prepared chat messages after querying layout at width 260, and separately retain 64 independent populated 80 × 24 glyph fields using index updates. The larger field cohort makes its heap change visible above Android’s accounting granularity. They use the existing corpus, typography, palette, and variants. Input fixtures and the runtime exist before the baseline; public handles and any cached layout data remain alive through the held snapshot and are released before the final snapshot.

The iOS path includes JSI/Hermes ownership; Android uses the same bindings as its timing tests. See the [counter definitions and sampling method](../README.md#memory).

## Recording results

The runner automatically updates the platform’s memory subsection after all three processes pass. After running the full timing suite on a platform, replace the timing tables in its section in [results.md](results.md) with the date, device, build configuration, and measurements. Keep only the latest run for each platform.

Console logs are saved under `benchmarks/.results/`. AndroidX also writes detailed reports under `android/build/outputs/connected_android_test_additional_output/`.
