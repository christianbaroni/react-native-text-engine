import { createTextEngineRuntime } from 'react-native-text-engine/worklets';
import type { WorkletRuntime } from 'react-native-worklets';

let chatRuntime: WorkletRuntime | undefined;
let fieldRuntime: WorkletRuntime | undefined;

export function getChatTextEngineRuntime(): WorkletRuntime {
  return (chatRuntime ??= createTextEngineRuntime({
    name: 'text-engine-chat-runtime',
  }));
}

export function getFieldTextEngineRuntime(): WorkletRuntime {
  return (fieldRuntime ??= createTextEngineRuntime({
    animationQueuePollingRate: 1000 / 60,
    enableEventLoop: true,
    name: 'text-engine-field-runtime',
  }));
}
