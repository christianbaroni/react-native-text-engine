import { createBaseStore, createStoreActions } from '@storesjs/stores';

export type Demo = 'chat' | 'field';
export type WidthMode = 'compact' | 'phone' | 'wide';

type UiState = {
  chatWidthMode: WidthMode;
  demo: Demo;
  hasMountedChat: boolean;
  setChatWidthMode: (widthMode: WidthMode) => void;
  setDemo: (demo: Demo) => void;
};

export const useUiStore = createBaseStore<UiState>(set => ({
  chatWidthMode: 'phone',
  demo: 'field',
  hasMountedChat: false,
  setChatWidthMode: chatWidthMode => set({ chatWidthMode }),
  setDemo: demo =>
    set(state => ({
      demo,
      hasMountedChat: state.hasMountedChat || demo === 'chat',
    })),
}));

export const uiActions = createStoreActions(useUiStore);
