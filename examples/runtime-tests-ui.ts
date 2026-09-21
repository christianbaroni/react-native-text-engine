import { runOnUISync } from 'react-native-worklets';

// Exercise the UI runtime before the text-engine worklets entrypoint installs it.
const uiBindingsBeforeInstallation = runOnUISync(() => {
  'worklet';
  return typeof globalThis.__RNTextEngineMeasure === 'function';
});

if (uiBindingsBeforeInstallation) throw new Error('Runtime test must start before UI text bindings are installed');

console.info('RNTE_UI_BEFORE_INSTALL_PASS');
