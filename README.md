# React Native Text Engine

Native text measurement, layout, and rendering primitives for React Native.

`react-native-text-engine` exposes those primitives to JavaScript and Worklet threads through three APIs:

- `TextView` renders text from direct props.
- Prepared text stores text and typography in a native handle that can be measured, laid out at different widths, and rendered later.
- Glyph fields draw a fixed grid of character cells whose contents can be replaced without rebuilding the grid.

Operations are synchronous and handle based, so measurement, layout, and grid updates can run in animation, virtualization, and custom layout code.

## Installation

```sh
yarn add react-native-text-engine
```

Worklet helpers require `react-native-worklets`:

```sh
yarn add react-native-worklets
```

On iOS:

```sh
cd ios
pod install
```

## TextView

`TextView` is the direct rendering API. Text and typography are passed as props, and the view can be wrapped with `Animated.createAnimatedComponent`.

```tsx
import { TextView } from 'react-native-text-engine';

export function PriceLabel() {
  return <TextView color="#111" fontFamily="Inter" fontSize={17} fontWeight="700" tabularNumbers text="$123.45" />;
}
```

The primary text input is the `text` prop. `TextView` also accepts text props, including:

- `allowFontScaling`
- `anchorToCapHeight`
- `color`
- `ellipsizeMode`
- `fontFamily`
- `fontSize`
- `fontWeight`
- `fontStyle`
- `letterSpacing`
- `lineHeight`
- `numberOfLines`
- `selectable`
- `tabularNumbers`
- `textAlign`

`selectable` enables native text selection. Without it, the view is display only.

`anchorToCapHeight` changes the measured text band. When it is true, the band starts at the first visible line's cap-height top and ends at the last visible line's baseline. The glyphs are still drawn normally.

### Inline Runs

Inline runs apply style ranges inside one string.

```tsx
import { TextView, createTextViewRunPayload } from 'react-native-text-engine';

const runs = createTextViewRunPayload([
  { start: 0, end: 4, style: { fontWeight: '700' } },
  { start: 5, end: 9, style: { fontStyle: 'italic' } },
]);

<TextView text="Bold text" fontSize={17} lineHeight={24} {...runs} />;
```

Run ranges are UTF-16 offsets. They must be sorted, non-overlapping, and inside the string bounds.

### JSX Children

Plain textual children can be compiled to the `text` prop with the optional Babel plugin:

```js
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['react-native-text-engine/babel-plugin'],
};
```

`TextView` does not flatten arbitrary children during render. The plugin only rewrites child text when the conversion can happen at build time.

## Prepared Text

Prepared text is text plus typography stored in native memory. The JavaScript object contains a numeric handle. That handle is valid for measurement, layout, line geometry, rendering, and Worklet calls until it is released.

```ts
import { createPreparedText, type TextMeasureStyle } from 'react-native-text-engine';

const style: TextMeasureStyle = {
  fontFamily: 'Inter',
  fontSize: 17,
  lineHeight: 24,
};

const message = createPreparedText('Hello world', style);

const layout = message.layout({
  width: 320,
  maxLines: 3,
  ellipsizeMode: 'tail',
});

layout.width;
layout.height;
layout.lineCount;
layout.lastLineWidth;

message.release();
```

`createPreparedText()` prepares the string and style. `layout()` supplies the width and line options for a particular layout result.

### PreparedTextView

`PreparedTextView` renders an existing prepared handle.

```tsx
import { PreparedTextView, createPreparedText } from 'react-native-text-engine';

const title = createPreparedText('Prepared once', {
  fontFamily: 'Inter',
  fontSize: 20,
  lineHeight: 26,
});

<PreparedTextView handle={title.handle} style={{ width: 320 }} />;
```

Rendering does not release the handle. Release it when it is no longer needed.

### One-Shot Measurement

One-shot measurement returns metrics without keeping a prepared handle.

```ts
import { measureText, measureTextWidth } from 'react-native-text-engine';

const width = measureTextWidth('123.45', {
  fontSize: 17,
  fontWeight: '700',
  tabularNumbers: true,
});

const block = measureText('Long paragraph...', { fontSize: 17, lineHeight: 24 }, { width: 320 });
```

### Batch APIs

Prepared text functions accept either a single item or an array.

```ts
import { createPreparedText, layoutPreparedText, releasePreparedText } from 'react-native-text-engine';

const prepared = createPreparedText(messages, style);
const layouts = layoutPreparedText(prepared, { width: contentWidth });

releasePreparedText(prepared);
```

The array form prepares, lays out, or releases many handles in one native call.

### Line Geometry

`lines()` returns every visible line for a layout request.

`nextLine()` returns the next visible line beginning at a UTF-16 offset. Its width argument applies to that line, so callers can build variable-width text flows.

```ts
const lines = message.lines({ width: 320 });
const next = message.nextLine(0, 220);
```

Line ranges use UTF-16 offsets. A line's `end` and `width` describe visible text. Trailing whitespace is not included.

## Glyph Fields

A glyph field is a fixed `columns` by `rows` grid. Creation sets the grid geometry, typography, alignment, and style variants. Updates replace the glyph and variant index for each cell.

```tsx
import { GlyphFieldView, createGlyphField, type GlyphFieldVariant } from 'react-native-text-engine';

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

field.update(glyphs, variantIndices);

<GlyphFieldView handle={field.handle} style={{ width: 360, height: 480 }} />;
```

`field.update()` accepts a string of glyphs or a `Uint8Array` of indices into `glyphPalette`. `variantIndices` selects the style variant for each cell.

Every update must match the grid:

- `glyphs.length === columns * rows`, or `glyphIndices.length === columns * rows`
- `variantIndices.length === columns * rows`
- every variant index points to an entry in `variants`

`field.release()` frees the native grid.

## Worklets

Importing the Worklets entrypoint installs Text Engine functions into the Worklets UI runtime.

```ts
import { measureTextsInRuntime } from 'react-native-text-engine/worklets';
```

The Worklets entrypoint exports:

- `createPreparedTextsInRuntime()`
- `measureTextsInRuntime()`
- `layoutPreparedTextsInRuntime()`
- `layoutNextLineInRuntime()`
- `updateGlyphFieldInRuntime()`
- `createGlyphFieldBuffersInRuntime()`
- `commitGlyphFieldBuffersInRuntime()`

```ts
import { layoutNextLineInRuntime, updateGlyphFieldInRuntime } from 'react-native-text-engine/worklets';

const next = layoutNextLineInRuntime(prepared.handle, 0, 220);
updateGlyphFieldInRuntime(field.handle, glyphs, variantIndices);
```

`createTextEngineRuntime()` creates a dedicated Worklets runtime with Text Engine already installed. If an initializer is provided, it runs after installation.

```ts
import { createTextEngineRuntime } from 'react-native-text-engine/worklets';

const runtime = createTextEngineRuntime({ name: 'text-engine-layout' });
```

## App Defaults

The package ships with no app-wide defaults.

An app can define build-time defaults in `react-native-text-engine.config.ts` or `react-native-text-engine.config.js` at the app root:

```ts
import { defineTextEngineDefaults } from 'react-native-text-engine/config';

export default defineTextEngineDefaults({
  anchorToCapHeight: true,
  fontFamily: 'Inter',
  fontSize: 17,
  lineHeight: 24,
});
```

Defaults fill undefined fields only. Explicit props and options take precedence.

Defaults are applied to:

- prepared text creation
- one-shot measurement
- Worklet measurement and layout helpers
- glyph-field typography fields omitted from `createGlyphField()`
- selected direct view props such as `anchorToCapHeight`, `allowFontScaling`, and `tabularNumbers`

`TextView` does not read typography defaults from its `style` prop. Put typography on direct props when app defaults should fill missing values.

The config is read during the native build. Rebuild the app after changing it.

## Native Resources

Prepared text and glyph fields allocate native resources. Release handles when they are no longer needed:

```ts
prepared.release();
releasePreparedText(preparedArray);
field.release();
```

## Text Style

`TextMeasureStyle` contains the text fields used by measurement and Text Engine's native views:

- `allowFontScaling`
- `color`
- `fontFamily`
- `fontSize`
- `fontStyle`
- `fontWeight`
- `includeFontPadding`
- `letterSpacing`
- `lineHeight`
- `tabularNumbers`
- `textBreakStrategy`

Layout options are separate: `anchorToCapHeight`, `ellipsizeMode`, `maxLines`, and `width`.

## Example App

The example app in [`examples/`](./examples) shows:

- `TextView` and prepared text in the type demo
- prepared text measurement in the chat demo
- glyph fields in the field and fire demos

## Benchmarks

See the [TextView vs React Native Text comparison](benchmarks/rn-text/README.md) and [library benchmarks](benchmarks/library/README.md) for results and run instructions.
