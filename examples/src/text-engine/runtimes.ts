import { createTextEngineRuntime } from 'react-native-text-engine/worklets';
import type { WorkletRuntime } from 'react-native-worklets';

let chatRuntime: WorkletRuntime | null = null;

export function getChatTextEngineRuntime(): WorkletRuntime {
  if (chatRuntime) return chatRuntime;

  chatRuntime = createTextEngineRuntime({ name: 'text-engine-chat-runtime' });
  return chatRuntime;
}
