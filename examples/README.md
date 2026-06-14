# React Native Text Engine Example

This app shows the package running in real React Native UI.

It focuses on the two main primitives in `react-native-text-engine`:

- prepared text for flowing text
- glyph fields for fixed-grid text surfaces

## What the demos show

### Text Field

The text field demo is a fixed-grid text surface driven by a live simulation on the UI runtime.

It uses a native glyph field, not a normal text view. Each frame updates:

- the glyph in each cell
- the style variant index for each cell

The native field owns drawing and style caches.

This is the package’s example of a text surface where the changing value is cell content, not paragraph layout.

### AI Chat

The chat demo is a long conversation surface built around prepared text.

It prepares message text once, measures layout for the active width, and feeds those exact heights into a worklet-driven list. Rows render from prepared text handles instead of rebuilding normal React text layout on demand.

This is the package’s example of flowing text whose layout needs to be known before rows mount.

### Type

The Type demo is a typographic composition built from prepared-text geometry.

It uses exact line layout to resolve a real wrapped drop cap and a shrinkwrapped pull quote before render, then displays the result with native text surfaces.

This is the package’s example of prepared text owning editorial composition rather than just plain block measurement.

### Fire

The Fire demo is a proportional typographic field driven by a live brightness simulation.

It writes one native glyph field every frame using precomputed glyph lookup tables, measured serif variants, and a touch-reactive particle current.

This is the package’s example of a glyph field owning the whole effect from stable geometry through final composition.

## Run

Use Node 22 or newer.

```sh
cd examples
yarn install
yarn start

# in another terminal
yarn ios
# or
yarn android
```

If iOS native dependencies change:

```sh
cd ios
pod install
```

## Local package setup

The example depends on the package through `portal:..`.

That means:

- edits in the root package are visible directly inside the example app
- you do not need to publish or pack the library to try a change
- Metro must keep React, React Native, Reanimated, and Worklets owned by the app copy rather than the linked package copy

That last part is already handled in the example’s Metro config.

## App structure

The app has one shell with a floating switch between:

- `Text Field`
- `Fire`
- `Type`
- `AI Chat`

The shell keeps the chat demo mounted after first entry so switching back and forth does not rebuild the whole chat surface each time.

## When to use this app

Use the example app when you need to verify:

- package changes in real React Native UI
- native view behavior on iOS and Android
- worklet installation and runtime behavior
- text measurement or glyph-field behavior under live interaction

If you only need the public package surface, read the root [`README.md`](../README.md) first.
