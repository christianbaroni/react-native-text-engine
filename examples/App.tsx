import React, { useLayoutEffect, useState } from 'react';
import { Platform, StatusBar, StyleSheet, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ChatDemo } from './src/demos/ChatDemo';
import { TextFieldDemo } from './src/demos/TextFieldDemo';
import { PillSwitch } from './src/components/PillSwitch';
import { uiActions, useUiStore } from './src/state/uiStore';
import { demoTheme } from './src/theme/demoTheme';

const DEMO_OPTIONS = [
  { label: 'Text Field', value: 'field' },
  { label: 'AI Chat', value: 'chat' },
] as const;

function App(): React.JSX.Element {
  const demo = useUiStore(state => state.demo);
  const [hasMountedChat, setHasMountedChat] = useState(demo === 'chat');

  useLayoutEffect(() => {
    if (demo !== 'chat') return;
    setHasMountedChat(true);
  }, [demo]);

  return (
    <>
      <StatusBar barStyle="light-content" />
      <SafeAreaProvider>
        <GestureHandlerRootView style={styles.root}>
          <View style={styles.shell}>
            <View pointerEvents="box-none" style={styles.nav}>
              <PillSwitch options={DEMO_OPTIONS} onChange={uiActions.setDemo} value={demo} />
            </View>
            <View style={styles.content}>
              <View
                pointerEvents={demo === 'field' ? 'auto' : 'none'}
                style={[styles.demoLayer, demo === 'field' ? styles.visible : styles.hidden]}
              >
                <TextFieldDemo isActive={demo === 'field'} />
              </View>
              {hasMountedChat ? (
                <View
                  pointerEvents={demo === 'chat' ? 'auto' : 'none'}
                  style={[styles.demoLayer, demo === 'chat' ? styles.visible : styles.hidden]}
                >
                  <ChatDemo isActive={demo === 'chat'} />
                </View>
              ) : null}
            </View>
          </View>
        </GestureHandlerRootView>
      </SafeAreaProvider>
    </>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
    position: 'relative',
  },
  demoLayer: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  hidden: {
    opacity: 0,
  },
  nav: {
    alignItems: 'center',
    bottom: Platform.OS === 'ios' ? 34 : 24,
    justifyContent: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
    zIndex: 10,
  },
  root: {
    flex: 1,
  },
  shell: {
    backgroundColor: demoTheme.root,
    flex: 1,
  },
  visible: {
    opacity: 1,
  },
});

export default App;
