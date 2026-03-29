import fs from 'node:fs/promises';
import path from 'node:path';
import type { RawContent, SourceReader } from './types.ts';

export const jsonReader: SourceReader = {
  canHandle(input: string): boolean {
    return input.endsWith('.json');
  },

  async read(input: string): Promise<RawContent> {
    const resolved = path.resolve(input);
    const raw = await fs.readFile(resolved, 'utf8');
    const data = JSON.parse(raw);

    const text = typeof data === 'object'
      ? JSON.stringify(data, null, 2)
      : String(data);

    return {
      text,
      sourceType: 'json',
      source: resolved,
      title: data?.title ?? data?.title_ko ?? path.basename(resolved, '.json'),
    };
  },
};
