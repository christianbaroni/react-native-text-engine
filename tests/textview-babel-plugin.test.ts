import { transformSync } from '@babel/core';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { describe, expect, it } from 'vitest';
import textViewBabelPlugin from '../lib/babel-plugin/babel-plugin-textview.cjs';

function transform(code: string): string {
  const result = transformSync(code, {
    babelrc: false,
    configFile: false,
    filename: 'example.tsx',
    parserOpts: {
      plugins: ['jsx', 'typescript'],
    },
    plugins: [textViewBabelPlugin],
  });

  return result?.code ?? '';
}

function transformFileWithExamplesBabelConfig(relativeFilePath: string): string {
  const filename = path.resolve(relativeFilePath);
  const result = transformSync(fs.readFileSync(filename, 'utf8'), {
    babelrc: false,
    configFile: path.resolve('examples/babel.config.cts'),
    cwd: path.resolve('examples'),
    filename,
  });

  return result?.code ?? '';
}

describe('TextView Babel plugin', () => {
  it('rewrites plain textual TextView children into the native text prop', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export function Demo({ count }: { count: number }) {
        return <TextView style={styles.footerText}>{String(count)} characters</TextView>;
      }
    `);

    expect(output).toContain('<TextView');
    expect(output).toContain('style={styles.footerText}');
    expect(output).toContain('text={String(count) + " characters"}');
    expect(output).not.toContain('>characters</TextView>');
  });

  it('keeps single explicit String() children on the direct text prop fast path', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export function Demo({ count }: { count: number }) {
        return <TextView>{String(count)}</TextView>;
      }
    `);

    expect(output).toContain('<TextView text={String(count)}></TextView>');
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('keeps typed primitive children on the direct text prop fast path', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export function Demo({ count }: { count: number }) {
        return <TextView>{count}</TextView>;
      }
    `);

    expect(output).toContain('coerceTextViewText as _rnteCoerceTextViewText');
    expect(output).toContain('<TextView text={_rnteCoerceTextViewText(count)}></TextView>');
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('rejects JSX spread children', () => {
    expect(() =>
      transform(`
      import { TextView } from 'react-native-text-engine';
      const content = ['one', 'two'];
      export const Demo = () => <TextView>{...content}</TextView>;
    `)
    ).toThrow('spread children are not supported in TextView');
  });

  it('rewrites aliased and namespace TextView imports too', () => {
    const aliased = transform(`
      import { TextView as EngineText } from 'react-native-text-engine';

      export const Demo = () => <EngineText>alpha</EngineText>;
    `);

    const namespaced = transform(`
      import * as TextEngine from 'react-native-text-engine';

      export const Demo = () => <TextEngine.TextView>{"beta"}</TextEngine.TextView>;
    `);

    expect(aliased).toContain('<EngineText text="alpha"></EngineText>');
    expect(namespaced).toContain('<TextEngine.TextView text="beta"></TextEngine.TextView>');
  });

  it('rejects mixed text ownership with both children and the text prop', () => {
    expect(() =>
      transform(`
        import { TextView } from 'react-native-text-engine';

        export const Demo = () => <TextView text="alpha">beta</TextView>;
      `)
    ).toThrow('RNTextEngine: TextView JSX child text conflicts with the explicit `text` prop. Choose one text owner.');
  });

  it('rewrites nested children by hoisting text fragments into nested TextView text segments', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = () => (
        <TextView>
          alpha <Foo />{" beta"}
        </TextView>
      );
    `);

    expect(output).toContain('<TextView><TextView text="alpha "');
    expect(output).toContain('<Foo />');
    expect(output).toContain('text=" beta"');
  });

  it('rewrites text inside fragments into nested TextView text segments', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = () => (
        <TextView>
          <>
            alpha <Foo />
          </>
          <>{' beta'}</>
        </TextView>
      );
    `);

    expect(output).toContain('<TextView><TextView text="alpha "');
    expect(output).toContain('<Foo />');
    expect(output).toMatch(/<TextView text=['"] beta['"]/);
    expect(output).not.toContain('<>');
  });

  it('rewrites opaque children forwarding through a runtime normalizer helper', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ children }: { children: React.ReactNode }) => <TextView>{children}</TextView>;
    `);

    expect(output).toContain('normalizeTextViewChildren as _rnteNormalizeTextViewChildren');
    expect(output).toContain('<TextView>{_rnteNormalizeTextViewChildren(children, TextView)}</TextView>');
  });

  it('rewrites single opaque expression children through the runtime normalizer helper', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ value }: { value: unknown }) => <TextView>{value}</TextView>;
    `);

    expect(output).toContain('normalizeTextViewChildren as _rnteNormalizeTextViewChildren');
    expect(output).toContain('<TextView>{_rnteNormalizeTextViewChildren(value, TextView)}</TextView>');
  });

  it('rewrites mixed ReactNode expression and static text through the runtime normalizer helper', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ value }: { value: React.ReactNode }) => (
        <TextView>{value} chars</TextView>
      );
    `);

    expect(output).toContain('normalizeTextViewChildren as _rnteNormalizeTextViewChildren');
    expect(output).toContain('_rnteNormalizeTextViewChildren([value, " chars"], TextView)');
  });

  it('rewrites typed arithmetic text expressions through coerceTextViewText on the direct text path', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ config }: { config: { rows: number; cols: number } }) => (
        <TextView>{config.rows * config.cols} characters</TextView>
      );
    `);

    expect(output).toContain('coerceTextViewText as _rnteCoerceTextViewText');
    expect(output).toContain('text={_rnteCoerceTextViewText(config.rows * config.cols) + " characters"}');
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('rewrites nested numeric text segments through coerceTextViewText instead of the runtime normalizer', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ count }: { count: number }) => (
        <TextView>
          Total: {count} <TextView text="items" />
        </TextView>
      );
    `);

    expect(output).toContain('coerceTextViewText as _rnteCoerceTextViewText');
    expect(output).toContain(
      '<TextView><TextView text={"Total: " + _rnteCoerceTextViewText(count) + " "} /><TextView text="items" /></TextView>'
    );
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('rewrites typed fragment text through coerceTextViewText instead of the runtime normalizer', () => {
    const output = transform(`
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ value }: { value: number }) => (
        <TextView>
          <>
            {value} chars
          </>
        </TextView>
      );
    `);

    expect(output).toContain('coerceTextViewText as _rnteCoerceTextViewText');
    expect(output).toContain('<TextView><TextView text={_rnteCoerceTextViewText(value) + " chars"} /></TextView>');
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('reuses an existing normalizeTextViewChildren import when present', () => {
    const output = transform(`
      import { normalizeTextViewChildren as normalize, TextView } from 'react-native-text-engine';

      export const Demo = ({ children }: { children: React.ReactNode }) => <TextView>{children}</TextView>;
    `);

    expect(output).not.toContain('_rnteNormalizeTextViewChildren');
    expect(output).toContain('<TextView>{normalize(children, TextView)}</TextView>');
  });

  it('adds a value import when normalizeTextViewChildren is already imported as type-only', () => {
    const output = transform(`
      import type { normalizeTextViewChildren } from 'react-native-text-engine';
      import { TextView } from 'react-native-text-engine';

      export const Demo = ({ children }: { children: React.ReactNode }) => <TextView>{children}</TextView>;
    `);

    expect(output).toContain('normalizeTextViewChildren as _rnteNormalizeTextViewChildren');
    expect(output).toContain("import type { normalizeTextViewChildren } from 'react-native-text-engine';");
    expect(output).toContain('<TextView>{_rnteNormalizeTextViewChildren(children, TextView)}</TextView>');
  });

  it('transforms the examples TextFieldDemo footer expression through coerceTextViewText', () => {
    const sourcePath = path.resolve('examples/src/demos/TextFieldDemo.tsx');
    const source = fs.readFileSync(sourcePath, 'utf8');
    const output = transform(source);

    expect(output).toContain('_rnteCoerceTextViewText(config.rows * config.cols) + " characters"');
    expect(output).not.toContain('normalizeTextViewChildren');
  });

  it('keeps TextFieldDemo footer expression safe under the full examples Babel config', () => {
    const output = transformFileWithExamplesBabelConfig('examples/src/demos/TextFieldDemo.tsx');
    expect(output).toContain('coerceTextViewText');
    expect(output).toContain('config.rows*config.cols');
    expect(output).not.toContain('normalizeTextViewChildren');
  });
});
