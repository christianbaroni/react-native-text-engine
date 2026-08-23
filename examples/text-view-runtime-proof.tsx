import { useEffect, useState } from 'react';
import { AppRegistry, Text, View, type LayoutChangeEvent } from 'react-native';
import { createGlyphField, createTextViewRunPayload, TextView } from 'react-native-text-engine';
import { getUIRuntimeHolder, scheduleOnRN, scheduleOnUI } from 'react-native-worklets';

const fontRuns = createTextViewRunPayload([{ start: 0, end: 4, style: { fontSize: 36, lineHeight: 48 } }]);
const colorRuns = createTextViewRunPayload([{ start: 0, end: 4, style: { color: '#1257ac' } }]);
const baseProps = { allowFontScaling: false, anchorToCapHeight: false, fontSize: 16, lineHeight: 24 };

function TextViewRuntimeProof() {
  const [heights, setHeights] = useState<Record<string, number>>({});
  const [workletReady, setWorkletReady] = useState(false);

  useEffect(() => {
    // Metro may defer the Worklets import until its first call.
    getUIRuntimeHolder();
    const field = createGlyphField({
      columns: 1,
      rows: 1,
      fontSize: 16,
      glyphPalette: 'M',
      lineHeight: 24,
      variants: [{ color: '#ffffff' }],
    });
    scheduleOnUI((handle: number) => {
      'worklet';
      const update = globalThis.__RNTextEngineUpdateGlyphFieldIndices;
      if (typeof update !== 'function') throw new Error('The glyph field did not install UI runtime bindings.');
      update(handle, new Uint8Array([0]), new Uint8Array([0]));
      scheduleOnRN(setWorkletReady, true);
    }, field.handle);
    return () => field.release();
  }, []);

  const recordHeight = (name: string) => (event: LayoutChangeEvent) => {
    const height = event.nativeEvent.layout.height;
    setHeights(previous => (previous[name] === height ? previous : { ...previous, [name]: height }));
  };
  const { plain = 0, colored = 0, direct = 0, nested = 0 } = heights;
  const passed = workletReady && plain > 0 && Math.abs(colored - plain) < 0.5 && direct > plain && Math.abs(nested - direct) < 0.5;
  const result = JSON.stringify({ passed, workletReady, heights });

  return (
    <View style={{ flex: 1, padding: 24, paddingTop: 64, backgroundColor: '#ffffff' }}>
      <TextView {...baseProps} text="MMMM" onLayout={recordHeight('plain')} />
      <TextView {...baseProps} {...colorRuns} text="MMMM" onLayout={recordHeight('colored')} />
      <TextView {...baseProps} {...fontRuns} text="MMMM" onLayout={recordHeight('direct')} />
      <TextView {...baseProps} onLayout={recordHeight('nested')}>
        <TextView text="MMMM" fontSize={36} lineHeight={48} />
      </TextView>
      <Text testID="text-view-proof" accessibilityLabel={result}>
        {result}
      </Text>
    </View>
  );
}

AppRegistry.registerComponent('example', () => TextViewRuntimeProof);
