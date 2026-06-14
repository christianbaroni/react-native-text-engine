declare module '@babel/core' {
  export function transformSync(
    code: string,
    options?: {
      babelrc?: boolean;
      configFile?: boolean | string;
      cwd?: string;
      filename?: string;
      parserOpts?: {
        plugins?: string[];
      };
      plugins?: unknown[];
      presets?: unknown[];
    }
  ): {
    code?: string | null;
  } | null;
}
