# Benchmarks

| Suite                                              | Measures                                                       | Results                               |
| -------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------- |
| [TextView vs React Native Text](rn-text/README.md) | Native text layout and cached measurements on iOS and Android  | [RN comparison](rn-text/results.md)   |
| [Library benchmarks](library/README.md)            | Text preparation, layout, and glyph updates on iOS and Android | [Library results](library/results.md) |

Run benchmark commands from the repository root after installing the library and [example app dependencies](../examples/README.md#run). iOS runs also require the example's CocoaPods dependencies. The RN Text comparison supports simulators and physical devices; the library benchmarks use a booted simulator. Android runs require a connected device or emulator.

Run logs are saved under `.results/` and ignored by Git. Each suite keeps its latest results for each platform in the file linked above.
