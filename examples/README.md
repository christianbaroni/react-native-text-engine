# React Native Pretext Example

This example app exists to prove two concrete use cases:

1. `TextFieldDemo`
   A dark, continuously changing text field driven by one Shared Value string on
   the UI runtime, with measured proportional glyph lookup precomputed once.

2. `ChatDemo`
   A long-conversation surface that uses exact `measureBatch` geometry for the
   active width and feeds that directly into a Shared Value recycled list built
   from the real worklet-list architecture.

## Run

```sh
yarn install
yarn start
yarn ios
# or
yarn android
```

The app depends on the local package via `portal:..`, so edits in the package
are visible directly from the example workspace.
