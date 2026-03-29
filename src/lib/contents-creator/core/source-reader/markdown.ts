import fs from 'node:fs/promises';
import path from 'node:path';
import type { RawContent, SourceReader } from './types.ts';

export const markdownReader: SourceReader = {
  canHandle(input: string): boolean {
    return input.endsWith('.md') || input.endsWith('.mdx');
  },

  async read(input: string): Promise<RawContent> {
    const resolved = path.resolve(input);
    const text = await fs.readFile(resolved, 'utf8');

    const titleMatch = text.match(/^#\s+(.+)$/m);

    return {
      text,
      sourceType: 'markdown',
      source: resolved,
      title: titleMatch?.[1]?.trim(),
    };
  },
};
