import { createElement, Fragment, isValidElement, type ComponentType, type ReactElement, type ReactNode } from 'react';

type TextViewComponentType = ComponentType<{
  children?: ReactNode;
  text?: string;
}>;

type NormalizationContext = {
  readonly TextViewComponent: TextViewComponentType;
  readonly normalized: ReactNode[];
  nextTextSegmentKey: number;
  pendingText: string;
};

function isIterableReactNode(value: object): value is Iterable<ReactNode> {
  return Symbol.iterator in value;
}

function flushPendingText(context: NormalizationContext): void {
  if (context.pendingText === '') return;
  context.normalized.push(
    createElement(context.TextViewComponent, {
      key: `rnte.${context.nextTextSegmentKey}`,
      text: context.pendingText,
    })
  );
  context.nextTextSegmentKey += 1;
  context.pendingText = '';
}

function appendText(value: string, context: NormalizationContext): void {
  if (value === '') return;
  context.pendingText += value;
}

function appendElement(node: ReactElement, context: NormalizationContext): void {
  flushPendingText(context);
  context.normalized.push(node);
}

function appendNormalizedChildren(node: ReactNode, context: NormalizationContext): void {
  if (node == null || node === false || node === true) return;

  if (typeof node === 'string' || typeof node === 'number' || typeof node === 'bigint') {
    appendText(String(node), context);
    return;
  }

  if (Array.isArray(node)) {
    for (const child of node) {
      appendNormalizedChildren(child, context);
    }
    return;
  }

  if (typeof node === 'object' && isIterableReactNode(node)) {
    for (const child of node) {
      appendNormalizedChildren(child, context);
    }
    return;
  }

  if (isValidElement<{ children?: ReactNode }>(node)) {
    if (node.type === Fragment) {
      appendNormalizedChildren(node.props.children, context);
      return;
    }

    appendElement(node, context);
    return;
  }

  throw new Error(
    'RNTextEngine: TextView child forwarding resolved to a non-text value. Forward textual content, React elements, iterables, arrays, or fragments.'
  );
}

/**
 * Lowers opaque ReactNode child forwarding into explicit `TextView` text spans.
 *
 * This keeps wrapper-style `<TextView>{children}</TextView>` usage lossless for
 * primitive text, arrays, fragments, and nested elements without making JS the
 * owner of final text flattening. Native still owns flattening the resulting
 * `TextView` subtree into one payload.
 */
export function normalizeTextViewChildren(children: ReactNode, TextViewComponent: TextViewComponentType): ReactNode {
  const context: NormalizationContext = {
    TextViewComponent,
    normalized: [],
    nextTextSegmentKey: 0,
    pendingText: '',
  };

  appendNormalizedChildren(children, context);
  flushPendingText(context);

  const normalized = context.normalized;
  if (normalized.length === 0) return null;
  if (normalized.length === 1) return normalized[0];
  return normalized;
}
