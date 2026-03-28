const OPENERS = [
  'We can ship this as a normal chat surface and still keep the text system exact.',
  'The current goal is not prettier text. The goal is deterministic layout under change.',
  'What matters here is removing the need for on-layout probes and hidden measurement views.',
  'This is the kind of substrate that makes long AI conversations feel structurally cheap.',
];

const DETAILS = [
  'A prepared message can be measured repeatedly as the viewport changes width, font scale, or split-screen mode, without rebuilding the message itself.',
  'That means list virtualization can own exact row heights before mount, and can keep them exact after width changes, instead of guessing and patching.',
  'The same prepared handle can also drive custom surfaces where the line count itself is part of the animation or interaction model.',
  'This is especially useful once the conversation gets large enough that ad hoc Text measurement starts coupling UI feel to measurement noise.',
];

const CLOSERS = [
  'The UI stays simple. The substrate gets stronger.',
  'Nothing about this requires React to become the owner of text geometry.',
  'The point is not another helper. The point is one owner for text facts.',
  'Once this exists, message rendering, collapse previews, and export surfaces can all consume the same underlying truth.',
];

export type ChatMessage = {
  id: string;
  role: 'assistant' | 'user';
  text: string;
};

function pick<T>(items: readonly T[], index: number): T {
  const item = items[index % items.length];
  if (item === undefined) {
    throw new Error('Chat data source unexpectedly returned no item.');
  }
  return item;
}

export function buildConversation(count: number): ChatMessage[] {
  return Array.from({ length: count }, (_, index) => {
    const role: ChatMessage['role'] = index % 3 === 0 ? 'user' : 'assistant';
    const opener = pick(OPENERS, index);
    const detail = pick(DETAILS, index * 3);
    const closer = pick(CLOSERS, index * 5);

    const text = role === 'assistant' ? `${opener} ${detail} ${closer}` : `Push this harder. ${detail} ${closer}`;

    return {
      id: `message-${index}`,
      role,
      text,
    };
  });
}
