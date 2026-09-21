import type { NodePath, PluginObj, PluginPass, types as t } from '@babel/core';

type BabelTypes = typeof t;
type ElementPath = NodePath<t.JSXElement>;
type ElementName = t.JSXOpeningElement['name'];
type ImportSpecifier = t.ImportDeclaration['specifiers'][number];
type Binding = ReturnType<ElementPath['scope']['getBinding']>;
type Annotation = t.TSType | t.FlowType | t.Noop | null | undefined;

interface TextViewPass extends PluginPass {
  textViewNames: Set<string>;
  textViewNamespaces: Set<string>;
  normalizeChildrenHelperName: string | null;
  coerceTextHelperName: string | null;
}

const PACKAGE_NAME = 'react-native-text-engine';
const NORMALIZE_HELPER_IMPORT = 'normalizeTextViewChildren';
const COERCE_TEXT_HELPER_IMPORT = 'coerceTextViewText';

function isImportedTextView(specifier: ImportSpecifier) {
  return specifier.type === 'ImportSpecifier' && specifier.imported.type === 'Identifier' && specifier.imported.name === 'TextView';
}

function isTypeOnlyImport(specifier: ImportSpecifier, declaration: t.ImportDeclaration) {
  const declarationImportKind = declaration.importKind ?? 'value';
  const specifierImportKind = (specifier.type === 'ImportSpecifier' ? specifier.importKind : null) ?? declarationImportKind;
  return declarationImportKind === 'type' || specifierImportKind === 'type';
}

function matchesTextViewElement(node: ElementName, state: TextViewPass) {
  if (node.type === 'JSXIdentifier') return state.textViewNames.has(node.name);

  return (
    node.type === 'JSXMemberExpression' &&
    node.object.type === 'JSXIdentifier' &&
    node.property.type === 'JSXIdentifier' &&
    state.textViewNamespaces.has(node.object.name) &&
    node.property.name === 'TextView'
  );
}

function jsxNameToExpression(t: BabelTypes, node: ElementName): t.Identifier | t.MemberExpression {
  if (node.type === 'JSXIdentifier') {
    return t.identifier(node.name);
  }

  if (node.type === 'JSXMemberExpression') {
    return t.memberExpression(jsxNameToExpression(t, node.object), t.identifier(node.property.name));
  }

  throw new Error('RNTextEngine: unsupported JSX element name for TextView child transform.');
}

function ensureHelperImport(
  t: BabelTypes,
  path: ElementPath,
  state: TextViewPass,
  importName: string,
  stateField: 'normalizeChildrenHelperName' | 'coerceTextHelperName',
  localNamePrefix: string
) {
  if (state[stateField] != null) return t.identifier(state[stateField]);

  const programPath = path.findParent(parent => parent.isProgram());
  const localName = path.scope.generateUidIdentifier(localNamePrefix).name;
  if (!programPath?.isProgram()) throw new Error('RNTextEngine: TextView transform requires a program scope.');
  programPath.unshiftContainer(
    'body',
    t.importDeclaration([t.importSpecifier(t.identifier(localName), t.identifier(importName))], t.stringLiteral(PACKAGE_NAME))
  );
  state[stateField] = localName;
  return t.identifier(localName);
}

function ensureNormalizeHelperImport(t: BabelTypes, path: ElementPath, state: TextViewPass) {
  return ensureHelperImport(t, path, state, NORMALIZE_HELPER_IMPORT, 'normalizeChildrenHelperName', 'rnteNormalizeTextViewChildren');
}

function ensureCoerceTextHelperImport(t: BabelTypes, path: ElementPath, state: TextViewPass) {
  return ensureHelperImport(t, path, state, COERCE_TEXT_HELPER_IMPORT, 'coerceTextHelperName', 'rnteCoerceTextViewText');
}

function isStringCallExpression(t: BabelTypes, node: t.Node) {
  return t.isCallExpression(node) && t.isIdentifier(node.callee, { name: 'String' }) && node.arguments.length === 1;
}

function unwrapExpression(t: BabelTypes, node: t.Node) {
  let next = node;
  while (true) {
    if (t.isTSAsExpression(next) || t.isTSSatisfiesExpression(next) || t.isTSTypeAssertion(next) || t.isParenthesizedExpression(next)) {
      next = next.expression;
      continue;
    }
    return next;
  }
}

function isChildrenIdentifier(t: BabelTypes, node: t.Node) {
  return t.isIdentifier(node, { name: 'children' });
}

function isChildrenMemberExpression(t: BabelTypes, node: t.Node) {
  if (t.isMemberExpression(node) && !node.computed) {
    return t.isIdentifier(node.property, { name: 'children' });
  }
  if (typeof t.isOptionalMemberExpression === 'function' && t.isOptionalMemberExpression(node) && !node.computed) {
    return t.isIdentifier(node.property, { name: 'children' });
  }
  return false;
}

function isTextLikeTypeAnnotation(t: BabelTypes, node: Annotation): boolean {
  if (node == null) return false;

  if (
    t.isTSStringKeyword(node) ||
    t.isTSNumberKeyword(node) ||
    t.isTSBigIntKeyword(node) ||
    t.isTSBooleanKeyword(node) ||
    t.isTSNullKeyword(node) ||
    (typeof t.isTSUndefinedKeyword === 'function' && t.isTSUndefinedKeyword(node))
  ) {
    return true;
  }

  if (t.isTSLiteralType(node)) {
    return (
      t.isStringLiteral(node.literal) ||
      t.isNumericLiteral(node.literal) ||
      (typeof t.isBigIntLiteral === 'function' && t.isBigIntLiteral(node.literal)) ||
      (typeof t.isBooleanLiteral === 'function' && t.isBooleanLiteral(node.literal))
    );
  }

  if (t.isTSUnionType(node)) {
    return node.types.every(type => isTextLikeTypeAnnotation(t, type));
  }

  if (typeof t.isTSParenthesizedType === 'function' && t.isTSParenthesizedType(node)) {
    return isTextLikeTypeAnnotation(t, node.typeAnnotation);
  }

  if (t.isTSTypeReference(node) && t.isIdentifier(node.typeName)) {
    return node.typeName.name === 'String' || node.typeName.name === 'Number';
  }

  return false;
}

function isReactNodeTypeAnnotation(t: BabelTypes, node: Annotation): boolean {
  if (node == null) return false;
  if (t.isTSArrayType(node) || (typeof t.isTSTupleType === 'function' && t.isTSTupleType(node))) return true;

  if (t.isTSUnionType(node)) {
    return node.types.some(type => isReactNodeTypeAnnotation(t, type));
  }

  if (typeof t.isTSParenthesizedType === 'function' && t.isTSParenthesizedType(node)) {
    return isReactNodeTypeAnnotation(t, node.typeAnnotation);
  }

  if (!t.isTSTypeReference(node)) return false;

  if (t.isIdentifier(node.typeName)) {
    return node.typeName.name === 'ReactNode' || node.typeName.name === 'ReactElement' || node.typeName.name === 'Element';
  }

  if (!t.isTSQualifiedName(node.typeName) || !t.isIdentifier(node.typeName.right)) return false;
  return ['ReactNode', 'ReactElement', 'Element'].includes(node.typeName.right.name);
}

function findObjectPatternPropertyTypeAnnotation(t: BabelTypes, pattern: t.ObjectPattern, name: string) {
  const patternAnnotation = t.isTSTypeAnnotation(pattern.typeAnnotation) ? pattern.typeAnnotation.typeAnnotation : null;
  if (!t.isTSTypeLiteral(patternAnnotation)) return null;

  for (const member of patternAnnotation.members) {
    if (!t.isTSPropertySignature(member)) continue;
    if (!t.isIdentifier(member.key, { name })) continue;
    return member.typeAnnotation?.typeAnnotation ?? null;
  }

  return null;
}

function getBindingTypeAnnotation(t: BabelTypes, binding: Binding, name: string) {
  if (binding == null) return null;

  if (binding.path.isVariableDeclarator()) {
    const { id, init } = binding.path.node;
    if (t.isIdentifier(id, { name }) && (t.isTSTypeAnnotation(id.typeAnnotation) || t.isTypeAnnotation(id.typeAnnotation))) {
      return id.typeAnnotation.typeAnnotation;
    }
    if (t.isObjectPattern(id)) {
      const propertyType = findObjectPatternPropertyTypeAnnotation(t, id, name);
      if (propertyType != null) return propertyType;
    }
    if (t.isTSAsExpression(init) || t.isTSSatisfiesExpression(init) || t.isTSTypeAssertion(init)) {
      return init.typeAnnotation;
    }
    return null;
  }

  if (
    binding.path.isIdentifier() &&
    (t.isTSTypeAnnotation(binding.identifier.typeAnnotation) || t.isTypeAnnotation(binding.identifier.typeAnnotation))
  ) {
    return binding.identifier.typeAnnotation.typeAnnotation;
  }

  if (binding.path.isObjectPattern()) {
    return findObjectPatternPropertyTypeAnnotation(t, binding.path.node, name);
  }

  if (binding.path.isAssignmentPattern()) {
    const left = binding.path.node.left;
    if (t.isIdentifier(left, { name }) && (t.isTSTypeAnnotation(left.typeAnnotation) || t.isTypeAnnotation(left.typeAnnotation))) {
      return left.typeAnnotation.typeAnnotation;
    }
  }

  return null;
}

function getExpressionTypeAnnotation(t: BabelTypes, path: ElementPath, node: t.Node) {
  if (t.isTSAsExpression(node) || t.isTSSatisfiesExpression(node) || t.isTSTypeAssertion(node)) {
    return node.typeAnnotation;
  }

  const expression = unwrapExpression(t, node);
  if (!t.isIdentifier(expression)) return null;
  return getBindingTypeAnnotation(t, path.scope.getBinding(expression.name), expression.name);
}

function hasNestedReactNodeSyntax(t: BabelTypes, node: t.Node): boolean {
  const expression = unwrapExpression(t, node);

  if (t.isJSXElement(expression) || t.isJSXFragment(expression) || t.isArrayExpression(expression)) {
    return true;
  }

  if (t.isConditionalExpression(expression)) {
    return hasNestedReactNodeSyntax(t, expression.consequent) || hasNestedReactNodeSyntax(t, expression.alternate);
  }

  if (t.isLogicalExpression(expression)) {
    return hasNestedReactNodeSyntax(t, expression.left) || hasNestedReactNodeSyntax(t, expression.right);
  }

  if (t.isSequenceExpression(expression)) {
    return expression.expressions.some(part => hasNestedReactNodeSyntax(t, part));
  }

  return false;
}

function canLowerExpressionToText(t: BabelTypes, path: ElementPath, node: t.Node): boolean {
  const expression = unwrapExpression(t, node);
  if (hasNestedReactNodeSyntax(t, expression)) return false;
  if (isChildrenIdentifier(t, expression) || isChildrenMemberExpression(t, expression)) return false;

  const annotation = getExpressionTypeAnnotation(t, path, node);
  if (annotation != null) {
    if (isReactNodeTypeAnnotation(t, annotation)) return false;
    if (isTextLikeTypeAnnotation(t, annotation)) return true;
  }

  if (
    t.isStringLiteral(expression) ||
    t.isNumericLiteral(expression) ||
    (typeof t.isBigIntLiteral === 'function' && t.isBigIntLiteral(expression)) ||
    t.isBooleanLiteral(expression) ||
    t.isNullLiteral(expression) ||
    t.isTemplateLiteral(expression) ||
    isStringCallExpression(t, expression)
  ) {
    return true;
  }

  if (t.isUnaryExpression(expression)) return true;

  if (t.isBinaryExpression(expression)) {
    if (expression.operator !== '+') return true;
    return canLowerExpressionToText(t, path, expression.left) && canLowerExpressionToText(t, path, expression.right);
  }

  if (t.isLogicalExpression(expression)) {
    return canLowerExpressionToText(t, path, expression.left) && canLowerExpressionToText(t, path, expression.right);
  }

  if (t.isConditionalExpression(expression)) {
    return canLowerExpressionToText(t, path, expression.consequent) && canLowerExpressionToText(t, path, expression.alternate);
  }

  if (t.isSequenceExpression(expression)) {
    const lastExpression = expression.expressions[expression.expressions.length - 1];
    return lastExpression != null && canLowerExpressionToText(t, path, lastExpression);
  }

  return false;
}

function buildChildren(t: BabelTypes, node: t.JSXElement | t.JSXFragment): t.Expression[] {
  const children = t.react.buildChildren(node);
  if (!children.every(child => !t.isJSXSpreadChild(child))) {
    throw new Error('RNTextEngine: spread children are not supported in TextView.');
  }
  return children;
}

function buildNormalizeChildrenCall(t: BabelTypes, path: ElementPath, state: TextViewPass, renderedChildren: t.Expression[]) {
  const normalizeHelper = ensureNormalizeHelperImport(t, path, state);
  const componentExpression = jsxNameToExpression(t, path.node.openingElement.name);
  const first = renderedChildren[0];
  const sourceNode =
    renderedChildren.length === 1 && first
      ? t.cloneNode(first, true)
      : t.arrayExpression(renderedChildren.map(child => t.cloneNode(child, true)));

  return t.callExpression(normalizeHelper, [sourceNode, componentExpression]);
}

function buildCoerceTextCall(t: BabelTypes, path: ElementPath, state: TextViewPass, node: t.Expression) {
  const coerceHelper = ensureCoerceTextHelperImport(t, path, state);
  return t.callExpression(coerceHelper, [t.cloneNode(node, true)]);
}

function buildTextExpression(t: BabelTypes, path: ElementPath, state: TextViewPass, children: t.Expression[]): t.Expression | null {
  const parts: t.Expression[] = [];

  for (const child of children) {
    if (t.isStringLiteral(child)) {
      if (child.value !== '') parts.push(child);
      continue;
    }

    if (t.isJSXElement(child) || t.isJSXFragment(child)) return null;

    if (t.isNumericLiteral(child)) {
      parts.push(t.stringLiteral(String(child.value)));
      continue;
    }

    if (isStringCallExpression(t, child)) {
      parts.push(child);
      continue;
    }

    if (!canLowerExpressionToText(t, path, child)) return null;
    parts.push(buildCoerceTextCall(t, path, state, child));
  }

  return parts.length === 0 ? null : parts.reduce((left, right) => t.binaryExpression('+', left, right));
}

function buildTextChildElement(t: BabelTypes, elementName: ElementName, textExpression: t.Expression) {
  const attribute = t.jsxAttribute(
    t.jsxIdentifier('text'),
    t.isStringLiteral(textExpression) ? textExpression : t.jsxExpressionContainer(textExpression)
  );

  return t.jsxElement(t.jsxOpeningElement(t.cloneNode(elementName), [attribute], true), null, [], true);
}

function buildNestedChildren(
  t: BabelTypes,
  path: ElementPath,
  state: TextViewPass,
  elementName: ElementName,
  children: t.Expression[]
): t.JSXElement['children'] {
  const nestedChildren: t.JSXElement['children'] = [];
  let textParts: t.Expression[] = [];

  function flushTextParts() {
    if (textParts.length === 0) return;
    const textExpression = buildTextExpression(t, path, state, textParts);
    if (textExpression == null) {
      nestedChildren.push(t.jsxExpressionContainer(buildNormalizeChildrenCall(t, path, state, textParts)));
    } else {
      nestedChildren.push(buildTextChildElement(t, elementName, textExpression));
    }
    textParts = [];
  }

  for (const child of children) {
    if (t.isJSXFragment(child)) {
      flushTextParts();
      nestedChildren.push(...buildNestedChildren(t, path, state, elementName, buildChildren(t, child)));
      continue;
    }

    if (t.isJSXElement(child)) {
      flushTextParts();
      nestedChildren.push(child);
      continue;
    }

    textParts.push(child);
  }

  flushTextParts();
  return nestedChildren;
}

function textViewBabelPlugin({ types: t }: { types: BabelTypes }): PluginObj<TextViewPass> {
  return {
    name: 'react-native-text-engine-textview',
    pre() {
      this.textViewNames = new Set();
      this.textViewNamespaces = new Set();
      this.normalizeChildrenHelperName = null;
      this.coerceTextHelperName = null;
    },
    visitor: {
      ImportDeclaration(path, state) {
        if (path.node.source.value !== PACKAGE_NAME) return;

        for (const specifier of path.node.specifiers) {
          if (isImportedTextView(specifier)) state.textViewNames.add(specifier.local.name);
          if (specifier.type === 'ImportNamespaceSpecifier') state.textViewNamespaces.add(specifier.local.name);
          if (isTypeOnlyImport(specifier, path.node)) continue;

          if (
            specifier.type === 'ImportSpecifier' &&
            specifier.imported.type === 'Identifier' &&
            specifier.imported.name === NORMALIZE_HELPER_IMPORT
          ) {
            state.normalizeChildrenHelperName = specifier.local.name;
          }

          if (
            specifier.type === 'ImportSpecifier' &&
            specifier.imported.type === 'Identifier' &&
            specifier.imported.name === COERCE_TEXT_HELPER_IMPORT
          ) {
            state.coerceTextHelperName = specifier.local.name;
          }
        }
      },
      JSXElement(path, state) {
        if (!matchesTextViewElement(path.node.openingElement.name, state)) return;

        const renderedChildren = buildChildren(t, path.node);
        if (renderedChildren.length === 0) return;

        const hasTextProp = path.node.openingElement.attributes.some(
          attribute => attribute.type === 'JSXAttribute' && attribute.name.type === 'JSXIdentifier' && attribute.name.name === 'text'
        );

        if (hasTextProp) {
          throw path.buildCodeFrameError(
            'RNTextEngine: TextView JSX child text conflicts with the explicit `text` prop. Choose one text owner.'
          );
        }

        const hasNestedElements = renderedChildren.some(child => t.isJSXElement(child) || t.isJSXFragment(child));
        if (hasNestedElements) {
          path.node.children = buildNestedChildren(t, path, state, path.node.openingElement.name, renderedChildren);
          return;
        }

        const textExpression = buildTextExpression(t, path, state, renderedChildren);
        if (textExpression == null) {
          path.node.children = [t.jsxExpressionContainer(buildNormalizeChildrenCall(t, path, state, renderedChildren))];
          return;
        }

        path.node.openingElement.attributes.push(
          t.jsxAttribute(
            t.jsxIdentifier('text'),
            t.isStringLiteral(textExpression) ? textExpression : t.jsxExpressionContainer(textExpression)
          )
        );
        path.node.children = [];
      },
    },
  };
}

export = textViewBabelPlugin;
