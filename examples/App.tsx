import React from 'react';
import { StatusBar, StyleSheet, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { PillSwitch } from './src/components/PillSwitch';
import { IS_IOS } from './src/constants';
import { ChatDemo } from './src/demos/ChatDemo';
import { FireDemo } from './src/demos/FireDemo';
import { TextFieldDemo } from './src/demos/TextFieldDemo';
import { TypeDemo } from './src/demos/TypeDemo';
import { uiActions, useUiStore } from './src/state/uiStore';
import { demoTheme } from './src/theme/demoTheme';

const DEMO_OPTIONS = [
  { label: 'Field', value: 'field' },
  { label: 'Fire', value: 'fire' },
  { label: 'Type', value: 'type' },
  { label: 'Chat', value: 'chat' },
] as const;

function App(): React.JSX.Element {
  const demo = useUiStore(state => state.demo);
  const hasMountedChat = useUiStore(state => state.hasMountedChat);

  const showFieldDemo = demo === 'field' || IS_IOS;
  const showFireDemo = demo === 'fire' || IS_IOS;

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
              {showFieldDemo ? (
                <View
                  pointerEvents={demo === 'field' ? 'auto' : 'none'}
                  style={[styles.demoLayer, demo === 'field' ? styles.visible : styles.hidden]}
                >
                  <TextFieldDemo isActive={demo === 'field'} />
                </View>
              ) : null}
              {showFireDemo ? (
                <View
                  pointerEvents={demo === 'fire' ? 'auto' : 'none'}
                  style={[styles.demoLayer, demo === 'fire' ? styles.visible : styles.hidden]}
                >
                  <FireDemo isActive={demo === 'fire'} />
                </View>
              ) : null}
              <View
                pointerEvents={demo === 'type' ? 'auto' : 'none'}
                style={[styles.demoLayer, demo === 'type' ? styles.visible : styles.hidden]}
              >
                <TypeDemo isActive={demo === 'type'} />
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
    bottom: IS_IOS ? 34 : 24,
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
