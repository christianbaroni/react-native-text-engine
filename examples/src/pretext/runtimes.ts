import { createRNPretextWorkletRuntime } from 'react-native-pretext/worklets';
import type { WorkletRuntime } from 'react-native-worklets';

let chatRuntime: WorkletRuntime | null = null;

export function getChatPretextRuntime(): WorkletRuntime {
  if (chatRuntime) return chatRuntime;

  chatRuntime = createRNPretextWorkletRuntime({ name: 'pretext-chat-runtime' });
  return chatRuntime;
}
