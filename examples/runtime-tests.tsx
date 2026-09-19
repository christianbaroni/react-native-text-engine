import React, { useEffect, useRef, useState } from 'react';
import { AppRegistry, Text, View, type LayoutChangeEvent } from 'react-native';
import { createGlyphField, createPreparedText, GlyphFieldView, measureText, PreparedTextView, TextView } from 'react-native-text-engine';
import { createTextEngineRuntime, measureTextsInRuntime, updateGlyphFieldInRuntime } from 'react-native-text-engine/worklets';
import { runOnRuntimeSync, runOnUISync } from 'react-native-worklets';
import { name as appName } from './app.json';

const text = 'Native runtime, prepared text, and Worklets agree.';
const style = { fontSize: 17, lineHeight: 24 };
const options = { width: 180 };

function createFixtures() {
  const expected = measureText(text, style, options);
  const prepared = createPreparedText(text, style);
  const runtime = createTextEngineRuntime({ name: 'text-engine-tests' });
  const uiLayout = runOnUISync(() => {
    'worklet';
    return measureTextsInRuntime([text], style, options)[0];
  });
  const workerLayout = runOnRuntimeSync(runtime, () => {
    'worklet';
    return measureTextsInRuntime([text], style, options)[0];
  });

  for (const layout of [prepared.layout(options), uiLayout, workerLayout]) {
    if (JSON.stringify(layout) !== JSON.stringify(expected)) {
      throw new Error(`Runtime measurement differs: ${JSON.stringify({ expected, layout })}`);
    }
  }

  const glyphs = createGlyphField({
    columns: 4,
    rows: 1,
    fontSize: 17,
    lineHeight: 24,
    variants: [{ color: '#ff0000' }],
  });
  const glyphHandle = glyphs.handle;
  runOnUISync(() => {
    'worklet';
    updateGlyphFieldInRuntime(glyphHandle, 'PASS', new Uint8Array(4));
  });

  return { glyphs, prepared, runtime };
}

function RuntimeTests() {
  const [fixtures] = useState(createFixtures);
  const [mounted, setMounted] = useState(true);
  const [status, setStatus] = useState('Checking native layouts');
  const layouts = useRef(new Set<string>());

  function onLayout(name: string, event: LayoutChangeEvent) {
    const { width, height } = event.nativeEvent.layout;
    if (width <= 0 || height <= 0) throw new Error(`${name} has an empty layout`);
    layouts.current.add(name);
    if (layouts.current.size === 4) {
      requestAnimationFrame(() => requestAnimationFrame(() => setMounted(false)));
    }
  }

  useEffect(() => {
    if (mounted) return;
    fixtures.prepared.layout(options);
    fixtures.prepared.release();
    fixtures.glyphs.release();
    let released = false;
    try {
      fixtures.prepared.layout(options);
    } catch {
      released = true;
    }
    if (!released) throw new Error('Released prepared text remained usable');
    const result = `RNTE_RUNTIME_TEST_PASS ${JSON.stringify({ layouts: [...layouts.current], ui: true, worker: true, released })}`;
    console.info(result);
    setStatus(result);
  }, [fixtures, mounted]);

  return (
    <View style={{ flex: 1, padding: 24, paddingTop: 80, backgroundColor: '#ffffff' }}>
      <Text>{status}</Text>
      {mounted && (
        <>
          <TextView text={text} {...style} style={{ width: 180 }} onLayout={event => onLayout('text', event)} />
          <TextView {...style} style={{ width: 180 }} onLayout={event => onLayout('nested', event)}>
            <TextView text="Nested " />
            <TextView text="native text" fontWeight="700" />
          </TextView>
          <PreparedTextView
            handle={fixtures.prepared.handle}
            style={{ width: 180, height: 96 }}
            onLayout={event => onLayout('prepared', event)}
          />
          <GlyphFieldView handle={fixtures.glyphs.handle} style={{ width: 180, height: 24 }} onLayout={event => onLayout('glyph', event)} />
        </>
      )}
    </View>
  );
}

AppRegistry.registerComponent(appName, () => RuntimeTests);
