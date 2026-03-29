# React Native Pretext

Native text measurement and rendering primitives for React Native.

Use `react-native-pretext` when you need text work to happen natively instead of inside normal React text rendering. In practice, that usually means one of two things:

1. You need exact text layout before render.
2. You need a fixed-grid text surface whose content changes cell by cell.

This package gives you a native primitive for each case.

## What it provides

### Prepared text

Prepared text is for normal flowing text.

You prepare text and typography once, get back a native handle, and ask the native text engine to lay that handle out at different widths later.

Use it for:

- chat bubbles
- exact virtualization
- worklet-driven layout
- custom UI that needs line counts or widths before render

### Glyph fields

Glyph fields are for fixed-grid text surfaces.

You create a field with stable geometry and a stable style palette, then replace the current glyphs and style indices later.

Use it for:

- proportional ASCII
- terminal-like surfaces
- text art driven by simulation
- any effect where the changing value is which glyph appears in each cell

Prepared text and glyph fields are different on purpose.

- Prepared text owns flowing text.
- Glyph fields own cell content.

If you try to force one through the other, you pay for the wrong work.

## Installation

Install the package:

```sh
yarn add react-native-pretext
```

If you want the worklet helpers, also install `react-native-worklets`:

```sh
yarn add react-native-worklets
```

On iOS:

```sh
cd ios
pod install
```

## Prepared text

### Prepare once, layout many times

```ts
import { layout, prepare, release, type TextMeasureStyle } from 'react-native-pretext';

const style: TextMeasureStyle = {
  fontFamily: 'SF Pro Rounded',
  fontSize: 17,
  fontWeight: '600',
  letterSpacing: 0.5,
  lineHeight: 24,
};

const message = prepare('Hello world', style);

const metrics = layout(message, {
  width: 320,
  maxLines: 3,
  ellipsizeMode: 'tail',
});

metrics.width;
metrics.height;
metrics.lineCount;
metrics.lastLineWidth;

release(message);
```

The split is simple:

- `prepare()` owns text and typography.
- `layout()` owns width-dependent results.

### One-shot measurement

If you do not need a persistent handle:

```ts
import { measure, measureWidth } from 'react-native-pretext';

const width = measureWidth('123.45', {
  fontSize: 17,
  fontWeight: '700',
  tabularNumbers: true,
});

const block = measure('Long paragraph...', { fontSize: 17, lineHeight: 24 }, { width: 320 });
```

### Inline runs

Prepared text can include inline style overrides inside one string:

```ts
import { prepare, type TextMeasureRun } from 'react-native-pretext';

const text = 'Ship bold code exactly';
const runs: readonly TextMeasureRun[] = [
  { start: 5, end: 9, style: { fontWeight: '700' } },
  { start: 10, end: 14, style: { fontFamily: 'Menlo' } },
];

const prepared = prepare(text, { fontSize: 17, lineHeight: 24 }, runs);
```

Runs are UTF-16 ranges into the source string. They must be sorted and non-overlapping.

### Batch work

For large collections:

```ts
import { layoutBatch, prepareBatch, releaseMany } from 'react-native-pretext';

const prepared = prepareBatch(messages, style);
const layouts = layoutBatch(prepared, { width: contentWidth });

releaseMany(prepared);
```

### Per-line geometry

If you need exact line metadata:

```ts
import { layoutLines, layoutNextLine } from 'react-native-pretext';

const lines = layoutLines(message, { width: 320 });
const next = layoutNextLine(message, 0, 220);
```

Use `layoutLines()` when one width applies to the whole block. Use `layoutNextLine()` when width changes line by line.

## Glyph fields

Create a glyph field when you have a fixed cell grid and a small style palette.

```ts
import { GlyphFieldView, createGlyphField, releaseGlyphField, updateGlyphField, type GlyphFieldVariant } from 'react-native-pretext';

const variants: readonly GlyphFieldVariant[] = [
  { color: 'rgba(196,163,90,0.18)', fontWeight: '300' },
  { color: 'rgba(196,163,90,0.92)', fontWeight: '800', fontStyle: 'italic' },
];

const field = createGlyphField({
  columns: 40,
  rows: 24,
  fontFamily: 'Georgia',
  fontSize: 18,
  lineHeight: 20,
  textAlign: 'center',
  variants,
});

const cellCount = 40 * 24;
const glyphs = ' '.repeat(cellCount);
const variantIndices = new Uint8Array(cellCount);

updateGlyphField(field, glyphs, variantIndices);

// Later:
releaseGlyphField(field);
```

Render the field from its handle:

```tsx
<GlyphFieldView handle={field.id} style={{ width: 360, height: 480 }} />
```

The update contract is strict:

- `glyphs.length` must equal `columns * rows`
- `variantIndices.length` must equal `columns * rows`
- each `variantIndices[i]` must point at one entry in `variants`

That is the whole model. The native field owns drawing and style caches. Your code only owns the current cell content.

## Native render surfaces

The package also exposes two minimal native text views:

```ts
import { PreparedTextView, TextView } from 'react-native-pretext';
```

- `TextView` renders direct text props.
- `PreparedTextView` renders from a prepared handle.

Use them when you want a native text surface but do not want React’s `<Text>` component to own layout on that path.

`selectable` opts into the interaction-oriented native owner. Leaving it off keeps the cheaper display path.

## Worklets

The core API is synchronous and React-free, so it can be used from worklets after the current runtime has been installed.

### Install into the UI runtime

If UI worklets will call pretext directly, do this once during startup:

```ts
import { installRNPretextInUIRuntime } from 'react-native-pretext/worklets';

installRNPretextInUIRuntime();
```

### Dedicated worklet runtime

If you want a separate runtime for text-heavy work:

```ts
import { createRNPretextWorkletRuntime } from 'react-native-pretext/worklets';

const runtime = createRNPretextWorkletRuntime({ name: 'pretext-layout' });
```

### Worklet helpers

The worklet entry currently exposes:

- `prepareBatchInRuntime()`
- `measureBatchInRuntime()`
- `layoutBatchInRuntime()`
- `updateGlyphFieldInRuntime()`

Example:

```ts
import { updateGlyphFieldInRuntime } from 'react-native-pretext/worklets';

updateGlyphFieldInRuntime(field.id, glyphs, variantIndices);
```

## Lifecycle

Handles own native memory, so cleanup is explicit:

- `release()` for one prepared text handle
- `releaseMany()` for many prepared text handles
- `releaseGlyphField()` for one glyph field handle

## Style surface

`TextMeasureStyle` is intentionally small. It includes the text properties that materially affect layout or native rendering:

- font family
- font size
- font weight
- font style
- letter spacing
- line height
- color
- tabular numbers
- font scaling, font padding, and break strategy where relevant

This package is not trying to mirror the full React Native text style API.

## When to use this package

Use it when React should consume native text results instead of owning the whole text problem itself.

That includes:

- exact text measurement before render
- chat and feed virtualization
- worklet-driven layout
- custom text surfaces outside `<Text>`
- fixed-grid glyph effects

Do not use it when normal React Native text layout is already good enough.

## Example app

The example app in [`examples/`](./examples) demonstrates both primitives:

- prepared text for chat measurement and rendering
- glyph fields for the ASCII demo
