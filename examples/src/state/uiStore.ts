import { createBaseStore, createStoreActions } from '@storesjs/stores';

export type Demo = 'chat' | 'field';
export type WidthMode = 'compact' | 'phone' | 'wide';

type UiState = {
  chatWidthMode: WidthMode;
  demo: Demo;
  setChatWidthMode: (widthMode: WidthMode) => void;
  setDemo: (demo: Demo) => void;
};

export const useUiStore = createBaseStore<UiState>(set => ({
  chatWidthMode: 'phone',
  demo: 'field',
  setChatWidthMode: chatWidthMode => set({ chatWidthMode }),
  setDemo: demo => set({ demo }),
}));

export const uiActions = createStoreActions(useUiStore);
