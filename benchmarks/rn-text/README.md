# TextView vs React Native Text

This benchmark compares native text layout in TextView and React Native's `Text` on iOS, using the same text, styles, and widths. [View results](results.md).

## Run

With an iOS simulator booted:

```sh
yarn perf:compare:ios
```

The runner builds the example in Release and runs the benchmark three times. It updates [results.md](results.md) after all three runs pass. A failed run leaves the existing results unchanged.

Set `IOS_DESTINATION_ID` to select a simulator. The build uses Node from `PATH`, or the executable specified by `NODE_BINARY`.

## What is measured

| Test                            | Work per pass                                                                                                        |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                | Build and lay out a Fabric shadow tree for 128 messages, then release it.                                            |
| Plain text creation and layout  | Create, measure, and release 128 distinct texts.                                                                     |
| Cached layout                   | Query previously measured text at six widths.                                                                        |
| Cached layout, two-line limit   | Repeat the cached queries with truncation after two lines.                                                           |
| Styled text creation and layout | Create, measure, and release 96 texts with changes in font size, weight, style, letter spacing, and tabular numbers. |

The strings are English, with fixed font sizes and uniform paragraph line heights. The creation tests include input construction and cleanup. Cached tests reuse prepared inputs and saved measurements. These are native layout timings; React rendering, drawing, and scrolling are outside the measurement.

## Method

Each run starts a new app process with the example UI disabled. After two warm-up samples, each implementation is measured nine times. The order alternates so neither implementation consistently runs first. Each creation or list-layout sample contains four passes; each cached sample contains 128. Timing includes autorelease-pool cleanup.

Before timing, the test checks all text and width combinations, including truncation and inline styles. Heights and Fabric frames must agree within one device pixel. Widths must fit their constraints: React Native can report the full container width for wrapped text, while TextView reports the width used by the glyphs.

The results table shows the median of the three run medians, with median absolute deviation to show variation between runs. All recorded samples are available below the table.

## Source

The native test is [RNTextEngineTextViewComparisonBenchmarks.mm](../../examples/ios/exampleTests/RNTextEngineTextViewComparisonBenchmarks.mm). The [runner](../run-ios-comparison.sh) saves each run under `benchmarks/.results/`; the [report script](../report.mjs) checks the logs and updates the results. To test the report script:

```sh
node --test benchmarks/test-report.mjs
```
