import type { RawContent, SourceReader } from './types.ts';
import { urlReader } from './url.ts';
import { markdownReader } from './markdown.ts';
import { pdfReader } from './pdf.ts';
import { jsonReader } from './json-reader.ts';
import { githubReader } from './github.ts';
import { folderReader } from './folder.ts';

// 우선순위 순서: 구체적인 것 → 일반적인 것
const readers: SourceReader[] = [
  markdownReader,
  pdfReader,
  jsonReader,
  githubReader,
  urlReader,
  folderReader, // 가장 마지막 (확장자 없는 경로를 폴더로 간주)
];

export function detectReader(input: string): SourceReader {
  const reader = readers.find((r) => r.canHandle(input));
  if (!reader) {
    throw new Error(`지원하지 않는 입력 형식입니다: ${input}`);
  }
  return reader;
}

export async function readSource(input: string): Promise<RawContent> {
  const reader = detectReader(input);
  return reader.read(input);
}
