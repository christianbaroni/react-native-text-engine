# React Native Pretext

Prepared text measurement and layout for React Native.

`react-native-pretext` gives React Native a `prepare` / `layout` text API backed by the platform’s native text engines.

It is built for cases where React components should not own text measurement:

- large AI chat conversations
- exact text-driven virtualization
- Shared Value UI that still needs width or line-count facts
- custom layout surfaces that need line metadata

## Model

The package has one core idea:

1. `prepare(text, style)` creates a prepared native text handle.
2. `layout(handle, options)` measures that prepared text at a width.
3. `layoutNextLine(handle, start, width)` steps through the text one visible line at a time when width changes per line.

That keeps one fact in one place:

- text + typography live in the prepared handle
- width-specific layout lives in the layout call

React can consume those facts, but it does not have to create them.

## Installation

```sh
yarn add react-native-pretext
cd ios && pod install
```

## API

### Prepare

```ts
import { prepare, release, type PreparedTextHandle, type TextMeasureStyle } from 'react-native-pretext';

const style: TextMeasureStyle = {
  fontFamily: 'SF Pro Rounded',
  fontSize: 17,
  fontWeight: '600',
  letterSpacing: 0.56,
  lineHeight: 24,
};

const prepared: PreparedTextHandle = prepare('Hello world', style);

// Later:
release(prepared);
```

### Layout

```ts
import { layout } from 'react-native-pretext';

const metrics = layout(prepared, {
  width: 320,
  maxLines: 3,
  ellipsizeMode: 'tail',
});

metrics.height;
metrics.lineCount;
metrics.width;
metrics.lastLineWidth;
```

### Per-line geometry

```ts
import { layoutLines, layoutNextLine } from 'react-native-pretext';

const result = layoutLines(prepared, { width: 320 });

result.lines[0];
// {
//   index: 0,
//   start: 0,
//   end: 14,
//   width: 118.5,
//   bottom: 24,
// }

const next = layoutNextLine(prepared, 0, 220);
if (next) {
  next.start;
  next.end;
  next.width;
}
```

### One-shot measurement

```ts
import { measure, measureWidth } from 'react-native-pretext';

const width = measureWidth('123.45', {
  fontSize: 17,
  fontWeight: '700',
  tabularNumbers: true,
});

const block = measure('Long paragraph...', style, { width: 320 });
```

### Inline runs

```ts
import { measure, prepare, type TextMeasureRun } from 'react-native-pretext';

const text = 'Ship bold code exactly';
const style = { fontSize: 17, lineHeight: 24 };
const runs: readonly TextMeasureRun[] = [
  { start: 5, end: 9, style: { fontWeight: '700' } },
  { start: 10, end: 14, style: { fontFamily: 'Menlo', tabularNumbers: true } },
];

const prepared = prepare(text, style, runs);
const layout = measure(text, style, { width: 320 }, runs);
```

Runs are UTF-16 offsets into the source string.
They must be sorted and non-overlapping.

### Batch work

```ts
import { prepareBatch, layoutBatch, releaseMany } from 'react-native-pretext';

const preparedMessages = prepareBatch(messages, style);
const layouts = layoutBatch(preparedMessages, { width: contentWidth });

// When the list is discarded:
releaseMany(preparedMessages);
```

## Worklets

The public API is React-free and sync, so it can be used from Reanimated worklets as long as the caller only moves serializable values across the boundary.

```ts
import { layout, prepare } from 'react-native-pretext';
import { useDerivedValue } from 'react-native-reanimated';

const prepared = prepare(message, style);

const measurement = useDerivedValue(() => {
  return layout(prepared, {
    width: bubbleWidth.value,
    maxLines: 2,
    ellipsizeMode: 'tail',
  });
});
```

For dedicated Worklets runtimes, use the `react-native-pretext/worklets` entry:

```ts
import { createRNPretextWorkletRuntime, layoutBatchInRuntime, prepareBatchInRuntime } from 'react-native-pretext/worklets';

const runtime = createRNPretextWorkletRuntime({ name: 'pretext-layout' });
```

That installs the native bindings into the created runtime before any caller initializer runs.

## Native text surfaces

The package also exposes minimal native text views for render paths that should stay outside React-owned text layout:

```ts
import { PreparedTextView, TextView } from 'react-native-pretext';
```

- `TextView` renders direct text props on iOS and Android.
- `PreparedTextView` renders directly from a prepared handle on iOS and Android.
- `selectable` opts into the interaction-oriented native text owner.
- leaving `selectable` off keeps the cheaper display-oriented path.

The split is intentional: selection and display have different runtime costs, so the package does not force the interaction path on every render surface.

## Style surface

`TextMeasureStyle` intentionally exposes the small, high-value subset of RN text style that materially affects exact layout or prepared-handle rendering:

```ts
type TextMeasureStyle = {
  allowFontScaling?: boolean;
  color?: string;
  fontFamily?: string;
  fontSize?: number;
  fontStyle?: 'italic' | 'normal';
  fontWeight?: string;
  includeFontPadding?: boolean;
  letterSpacing?: number;
  lineHeight?: number;
  tabularNumbers?: boolean;
  textBreakStrategy?: 'balanced' | 'highQuality' | 'simple';
};
```

This is not meant to mirror the entire Text style API.
Only layout-relevant or prepared-render-relevant facts belong here.

Inline overrides use the run-local subset:

```ts
type TextMeasureRunStyle = Pick<
  TextMeasureStyle,
  'color' | 'fontFamily' | 'fontSize' | 'fontStyle' | 'fontWeight' | 'letterSpacing' | 'lineHeight' | 'tabularNumbers'
>;
```

Block-level layout policy such as `allowFontScaling`, `includeFontPadding`, and
`textBreakStrategy` remains owned by the base `TextMeasureStyle`.

## Handle lifecycle

Prepared handles own native memory.

That means:

- call `release(handle)` when one prepared block is no longer needed
- call `releaseMany(handles)` for bulk cleanup

The package keeps lifecycle explicit on purpose.

## What the package owns

- prepared native text state
- exact width/height/line-count measurement
- optional line metadata
- variable-width line stepping
- worklet-safe sync calls

## What the package does not own

- React state management
- markdown parsing
- mixed-style attributed text runs
- custom truncation token rendering beyond native ellipsize behavior

Those can sit above this package.

## Architecture

The package uses:

- old/new architecture-compatible native module install path
- JSI globals for sync calls
- native registry-backed prepared handles
- native text engines as the source of truth on iOS and Android

The design artifacts for the package live in:

- [brief.md](./brief.md)
- [journal.md](./journal.md)
- [implementation-plan.md](./implementation-plan.md)
- [worklets-evaluation.md](./worklets-evaluation.md)

The example app lives in:

- [examples/App.tsx](./examples/App.tsx)
- [examples/src/demos/TextFieldDemo.tsx](./examples/src/demos/TextFieldDemo.tsx)
- [examples/src/demos/ChatDemo.tsx](./examples/src/demos/ChatDemo.tsx)

Those demos currently prove two intended RN surfaces:

- a continuously changing dark text field built from measured proportional glyph lookup and one Shared Value text owner on the UI runtime
- a long AI chat surface where exact text geometry feeds a transplanted Shared Value recycled list instead of React-owned row measurement

## Verification

Current verified checks in this repo:

- TypeScript surface passes `yarn typescript`
- publish build passes `yarn build`
- package artifact passes `npm pack --dry-run`
- example app source passes `yarn exec tsc --noEmit` in `examples/`
- example app source passes `yarn eslint App.tsx "src/**/*.{ts,tsx}"` in `examples/`

Native runtime still deserves an explicit old/new-architecture verification matrix, but the current repo is now coherent at the package layer and at the example app source layer.
