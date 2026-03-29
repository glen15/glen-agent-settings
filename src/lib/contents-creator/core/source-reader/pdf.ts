import fs from 'node:fs/promises';
import path from 'node:path';
import type { RawContent, SourceReader } from './types.ts';

export const pdfReader: SourceReader = {
  canHandle(input: string): boolean {
    return input.endsWith('.pdf');
  },

  async read(input: string): Promise<RawContent> {
    const resolved = path.resolve(input);
    const buffer = await fs.readFile(resolved);
    const uint8 = new Uint8Array(buffer);

    const pdfjsLib = await import('pdfjs-dist/legacy/build/pdf.mjs');
    const doc = await pdfjsLib.getDocument({ data: uint8 }).promise;

    const pages: string[] = [];
    for (let i = 1; i <= doc.numPages; i++) {
      const page = await doc.getPage(i);
      const content = await page.getTextContent();
      const text = content.items
        .filter((item) => 'str' in item)
        .map((item) => (item as { str: string }).str)
        .join(' ');
      pages.push(text);
    }

    return {
      text: pages.join('\n\n'),
      sourceType: 'pdf',
      source: resolved,
      title: path.basename(resolved, '.pdf'),
    };
  },
};
